#!/bin/bash
#
#  Copyright 2026 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -euo pipefail

echo "[$(date)] ==================== Starting Cleanup... ===================="

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"

export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 1. Delete Slurm cluster
echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
gcluster destroy "${CLUSTER_NAME}" --auto-approve || true

# 2. Delete Networks

echo "========================================================================="
echo " STARTING AUTOMATED NETWORK CLEANUP FOR CLUSTER: ${CLUSTER_NAME}"
echo "========================================================================="

echo "Discovering all VPC networks linked to the cluster..."
NETWORKS=$(gcloud compute networks list --project="${PROJECT_ID}" --format="value(name)" | grep "^${CLUSTER_NAME}" || true)

if [ -z "${NETWORKS}" ]; then
    echo "No VPC networks found starting with ${CLUSTER_NAME}. Everything is already clean!"
    exit 0
fi

echo "Found the following networks to process:"
echo "${NETWORKS}"
echo "-------------------------------------------------------------------------"

echo "=== 1. Wiping Global Firewall Rules ==="
FIREWALL_RULES=$(gcloud compute firewall-rules list \
    --project="${PROJECT_ID}" \
    --filter="network ~ ^${CLUSTER_NAME} OR name ~ ^${CLUSTER_NAME}" \
    --format="value(name)" || echo "")

if [ -n "${FIREWALL_RULES}" ]; then
    echo "Deleting matching firewall rules:"
    echo "${FIREWALL_RULES}"
    echo "${FIREWALL_RULES}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet
else
    echo "No matching firewall rules found."
fi

echo "=== 2. Tearing Down Network-Specific Infrastructure ==="
echo "${NETWORKS}" | while read -r net_name; do
    [ -z "${net_name}" ] && continue
    echo "Processing resources for network: ${net_name}"

    ROUTERS=$(gcloud compute routers list \
        --project="${PROJECT_ID}" \
        --regions="${REGION}" \
        --filter="network=${net_name}" \
        --format="value(name)" || echo "")

    if [ -n "${ROUTERS}" ]; then
        echo "  -> Deleting routers: ${ROUTERS}"
        echo "${ROUTERS}" | xargs -r gcloud compute routers delete --region="${REGION}" --project="${PROJECT_ID}" --quiet
    fi

    IPS=$(gcloud compute addresses list \
        --project="${PROJECT_ID}" \
        --regions="${REGION}" \
        --filter="name ~ ^${net_name}" \
        --format="value(name)" || echo "")

    if [ -n "${IPS}" ]; then
        echo "  -> Deleting IP reservations: ${IPS}"
        echo "${IPS}" | xargs -r gcloud compute addresses delete --region="${REGION}" --project="${PROJECT_ID}" --quiet
    fi

    SUBNETS=$(gcloud compute networks subnets list \
        --project="${PROJECT_ID}" \
        --regions="${REGION}" \
        --filter="network=${net_name}" \
        --format="value(name)" || echo "")

    if [ -n "${SUBNETS}" ]; then
        echo "  -> Deleting subnetworks:"
        echo "${SUBNETS}"
        echo "${SUBNETS}" | xargs -r gcloud compute networks subnets delete --region="${REGION}" --project="${PROJECT_ID}" --quiet
    fi
done

echo "-------------------------------------------------------------------------"
echo "Waiting 15 seconds for Google Cloud API dependencies to unlock..."
sleep 15

echo "=== 3. Final VPC Networks Destruction ==="
echo "${NETWORKS}" | while read -r net_name; do
    [ -z "${net_name}" ] && continue
    echo "Deleting core VPC network: ${net_name}..."
    gcloud compute networks delete "${net_name}" --project="${PROJECT_ID}" --quiet || \
    echo "Warning: Could not delete ${net_name} yet. If a lock occurred, please rerun in 1 minute."
done

echo "========================================================================="
echo " SUCCESS: All network resources for cluster ${CLUSTER_NAME} have been wiped!"
echo "========================================================================="

# 3. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${BUCKET_NAME}..."
gcloud storage buckets delete "gs://${BUCKET_NAME}" --quiet || true

echo "[$(date)] ==================== Cleanup Complete. ===================="
