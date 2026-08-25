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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[$(date)] ========== Deleting Ray cluster =========="
helm delete ray-cluster || true

echo "[$(date)] ========== Deleting GKE cluster =========="
gcloud container clusters delete ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --quiet || true

echo "[$(date)] ========== Deleting the Lustre filesystem =========="
gcloud lustre instances delete ${LUSTRE_NAME} \
    --location=${NODE_ZONE} \
    --quiet || true

echo "[$(date)] ========== Deleting VPC peering =========="
gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=${NETWORK} \
    --quiet || true

echo "[$(date)] ========== Deleting the Lustre private IP address range =========="
gcloud compute addresses delete ${LUSTRE_NAME}-range --global --quiet || true

echo "[$(date)] ========== Deleting RDMA and GVNIC subnets =========="
gcloud compute networks subnets delete ${GVNIC_NETWORK_PREFIX}-sub \
    --region=${CONTROL_PLANE_REGION} \
    --quiet || true

for N in $(seq 0 7); do
  gcloud compute networks subnets delete ${RDMA_NETWORK_PREFIX}-sub-$N \
    --region=${CONTROL_PLANE_REGION} --quiet || true &
done
wait

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_fwrules_and_network_cleanup]
echo "[$(date)] ========== Deleting firewall rules and networks =========="

NETWORKS=(
    "${RDMA_NETWORK_PREFIX}-net"
    "${GVNIC_NETWORK_PREFIX}-net"
    "${NETWORK}"
)

for NW in "${NETWORKS[@]}"; do

  # Skip if empty, named 'default', or not starting with a lowercase letter (invalid GCP resource name)
  if [[ "${NW}" == "default" || ! "${NW}" =~ ^[a-z] ]]; then
    echo "Skipping protected/invalid network: '${NW}'"
    continue
  fi

  echo "========== Deleting firewall rules for ${NW} =========="
  while true; do
      rules=$(gcloud compute firewall-rules list \
        --filter="network:${NW}" \
        --format="value(name)" \
        --project="${PROJECT_ID}")

        if [[ -z "${rules}" ]]; then
          echo "No firewall rules remain for ${NW}"
          break
        fi

        for rule in ${rules}; do
          echo "Deleting firewall rule ${rule}..."
          gcloud compute firewall-rules delete "${rule}" --project="${PROJECT_ID}" --quiet || true
        done

        sleep 3
      done

      echo "[$(date)] ========== Deleting network ${NW} =========="
      gcloud compute networks delete ${NW} --quiet || true
done
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_fwrules_and_network_cleanup]

echo "[$(date)] ========== Deleting local files =========="
rm -rf "${SCRIPT_DIR}/kubernetes-engine-samples"

echo "[$(date)] ========== Cleanup Complete =========="
