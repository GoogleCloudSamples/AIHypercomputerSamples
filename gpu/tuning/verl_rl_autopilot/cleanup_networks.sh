#!/bin/bash

# Copyright 2026 Google LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# Save user defined values from environment
USER_CLUSTER_NAME="${CLUSTER_NAME:-}"
USER_REGION="${CONTROL_PLANE_REGION:-}"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source defaults if env file exists
if [ -f "${SCRIPT_DIR}/0_env.sh" ]; then
    source "${SCRIPT_DIR}/0_env.sh"
fi

# Restore user defined values if they were set (overriding defaults)
if [ -n "${USER_CLUSTER_NAME}" ]; then
    CLUSTER_NAME="${USER_CLUSTER_NAME}"
fi
if [ -n "${USER_REGION}" ]; then
    CONTROL_PLANE_REGION="${USER_REGION}"
fi

# Ensure CLUSTER_NAME is set
if [ -z "${CLUSTER_NAME:-}" ]; then
    echo "Error: CLUSTER_NAME is not set. Please set it as an env var or in 0_env.sh"
    exit 1
fi

# Ensure CONTROL_PLANE_REGION is set
if [ -z "${CONTROL_PLANE_REGION:-}" ]; then
    echo "Error: CONTROL_PLANE_REGION is not set. Please set it as an env var or in 0_env.sh"
    exit 1
fi

echo "=== Starting Network Cleanup for Cluster: ${CLUSTER_NAME} in ${CONTROL_PLANE_REGION} ==="

# 1. Get Cluster Hash
echo "Retrieving cluster hash..."
if ! POD_RANGE=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${CONTROL_PLANE_REGION}" --format="value(ipAllocationPolicy.clusterSecondaryRangeName)" 2>/dev/null); then
    echo "Warning: Could not describe cluster ${CLUSTER_NAME}. It might already be deleted."
    if [ -t 0 ]; then
        echo "If you know the cluster hash (e.g. 4dbafcbf), enter it now, or press Enter to abort:"
        read -r HASH
    else
        echo "Error: Non-interactive shell and cluster hash could not be retrieved automatically."
        exit 1
    fi
    if [ -z "${HASH:-}" ]; then
        echo "Aborting."
        exit 1
    fi
else
    HASH=${POD_RANGE##*-}
    echo "Found cluster hash: ${HASH}"
fi

# 2. Find Networks
echo "Finding networks with hash ${HASH}..."
# Using --format="value(name)" to get a space-separated list
NETWORKS=$(gcloud compute networks list --filter="name:gke-anp-${HASH}" --format="value(name)")

if [ -z "${NETWORKS}" ]; then
    echo "No networks found for hash ${HASH}. Clean up might be already complete."
    exit 0
fi

echo "Found networks:"
echo "${NETWORKS}"

# 3. Find and Delete Firewall Rules
echo "Checking for firewall rules..."
FIREWALLS=$(gcloud compute firewall-rules list --filter="name:gke-anp-${HASH}" --format="value(name)")
if [ -n "${FIREWALLS}" ]; then
    echo "Deleting firewall rules..."
    # gcloud delete can take multiple names separated by space
    gcloud compute firewall-rules delete ${FIREWALLS} --quiet
else
    echo "No firewall rules found."
fi

# 4. Find and Delete Subnets
echo "Checking for subnetworks in region ${CONTROL_PLANE_REGION}..."
for NET in ${NETWORKS}; do
    # List subnetworks in the specific network and region
    SUBNETS=$(gcloud compute networks subnets list --regions="${CONTROL_PLANE_REGION}" --filter="network:${NET}" --format="value(name)" 2>/dev/null || true)
    if [ -n "${SUBNETS}" ]; then
        echo "Deleting subnetworks for ${NET} in ${CONTROL_PLANE_REGION}:"
        echo "${SUBNETS}"
        for SUB in ${SUBNETS}; do
            gcloud compute networks subnets delete "${SUB}" --region="${CONTROL_PLANE_REGION}" --quiet || true
        done
    else
        echo "No subnetworks found for ${NET}."
    fi
done

# 5. Delete Networks
echo "Deleting networks..."
for NET in ${NETWORKS}; do
    echo "Deleting network ${NET}..."
    gcloud compute networks delete "${NET}" --quiet || true
done

echo "=== Network Cleanup Complete ==="
