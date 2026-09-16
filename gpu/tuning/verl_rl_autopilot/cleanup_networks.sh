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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [ -f "0_env.sh" ]; then
  source 0_env.sh 2>/dev/null || true
fi

# Save user defined values from environment
USER_CLUSTER_NAME="${CLUSTER_NAME:-}"
USER_REGION="${CONTROL_PLANE_REGION:-}"

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

# 1. Get Cluster Hash (scoped strictly to this cluster to protect concurrent clusters)
if [ -z "${HASH:-}" ]; then
    echo "Retrieving cluster hash for ${CLUSTER_NAME}..."
    if POD_RANGE=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${CONTROL_PLANE_REGION}" --format="value(ipAllocationPolicy.clusterSecondaryRangeName)" 2>/dev/null); then
        HASH=${POD_RANGE##*-}
        echo "Found cluster hash: ${HASH}"
    else
        echo "Warning: Cluster ${CLUSTER_NAME} is not found or already deleted, and HASH is not provided."
        if [ -t 0 ]; then
            echo "If you know the cluster hash (e.g. 4dbafcbf), enter it now, or press Enter to skip:"
            read -r HASH || true
        fi
        if [ -z "${HASH:-}" ]; then
            echo "No cluster hash available to identify cluster-specific ANP networks. Skipping network cleanup to protect other clusters."
            exit 0
        fi
    fi
else
    echo "Using provided cluster hash: ${HASH}"
fi

# 2. Find Networks specifically matching this cluster hash
echo "Finding networks with hash ${HASH}..."
# Using --format="value(name)" to get a space-separated list
NETWORKS=$(gcloud compute networks list --filter="name:gke-anp-${HASH}" --format="value(name)")

if [ -z "${NETWORKS}" ]; then
    echo "No networks found for hash ${HASH}. Clean up might be already complete."
    exit 0
fi

echo "Found cluster-specific networks:"
echo "${NETWORKS}"

# 3. Find and Delete Firewall Rules matching this cluster hash
echo "Checking for firewall rules matching hash ${HASH}..."
FIREWALLS=$(gcloud compute firewall-rules list --filter="name:gke-anp-${HASH}" --format="value(name)")
if [ -n "${FIREWALLS}" ]; then
    echo "Deleting firewall rules..."
    gcloud compute firewall-rules delete ${FIREWALLS} --quiet || true
else
    echo "No firewall rules found."
fi

# 4. Find and Delete Subnets matching this cluster hash (with retries for NIC detachment)
echo "Checking for subnetworks in region ${CONTROL_PLANE_REGION}..."
for NET in ${NETWORKS}; do
    SUBNETS=$(gcloud compute networks subnets list --regions="${CONTROL_PLANE_REGION}" --filter="network:${NET}" --format="value(name)" 2>/dev/null || true)
    if [ -n "${SUBNETS}" ]; then
        echo "Deleting subnetworks for ${NET} in ${CONTROL_PLANE_REGION}:"
        echo "${SUBNETS}"
        for SUB in ${SUBNETS}; do
            for retry in {1..5}; do
                if gcloud compute networks subnets delete "${SUB}" --region="${CONTROL_PLANE_REGION}" --quiet 2>/dev/null; then
                    break
                fi
                echo "Subnet ${SUB} busy (waiting for NIC detach), retrying in 5s (attempt ${retry}/5)..."
                sleep 5
            done
        done
    else
        echo "No subnetworks found for ${NET}."
    fi
done

# 5. Delete Networks matching this cluster hash (with retries)
echo "Deleting networks for hash ${HASH}..."
for NET in ${NETWORKS}; do
    echo "Deleting network ${NET}..."
    for retry in {1..5}; do
        if gcloud compute networks delete "${NET}" --quiet 2>/dev/null; then
            break
        fi
        echo "Network ${NET} busy, retrying in 5s (attempt ${retry}/5)..."
        sleep 5
    done
done

echo "=== Network Cleanup Complete ==="
