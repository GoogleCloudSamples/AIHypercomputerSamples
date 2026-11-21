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

# shellcheck disable=SC2153

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${SCRIPT_DIR}/.tools:${PATH}"

echo "[$(date)] ========== Deleting Ray cluster =========="
if ! command -v helm &> /dev/null; then
  echo "Helm not found. Skipping Helm release deletion; deleting the cluster removes it."
elif gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${CONTROL_PLANE_REGION}"; then
  helm delete ray-cluster --wait --timeout=10m || true
else
  echo "Warning: couldn't get credentials for ${CLUSTER_NAME}; skipping the Helm release deletion." >&2
fi

echo "[$(date)] ========== Waiting for running cluster operations =========="
count=0
LIMIT=60
while [[ -n "$(gcloud container operations list \
    --project="${PROJECT_ID}" \
    --location="${CONTROL_PLANE_REGION}" \
    --filter="status=RUNNING AND targetLink~/clusters/${CLUSTER_NAME}($|/)" \
    --format="value(name)" 2>/dev/null || true)" ]]; do
  if [[ ${count} -ge ${LIMIT} ]]; then
    echo "Timeout waiting for running operations on ${CLUSTER_NAME}. Trying to delete anyway."
    break
  fi
  echo "Operations are still running on ${CLUSTER_NAME}. Waiting..."
  sleep 30
  count=$((count + 1))
done

echo "[$(date)] ========== Deleting GKE cluster =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_gke_cluster_cleanup]
gcloud container clusters delete "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${CONTROL_PLANE_REGION}" \
    --quiet || true
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_gke_cluster_cleanup]

echo "[$(date)] ========== Deleting the Lustre filesystem =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_cleanup]
gcloud lustre instances delete "${LUSTRE_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${LUSTRE_ZONE}" \
    --quiet || true
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_cleanup]

echo "[$(date)] ========== Deleting VPC peering =========="
delete_vpc_peering() {
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_vpc_peering_cleanup]
gcloud services vpc-peerings delete \
    --project="${PROJECT_ID}" \
    --service=servicenetworking.googleapis.com \
    --network="${NETWORK}" \
    --quiet
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_vpc_peering_cleanup]
}
vpc_peering_exists() {
  [[ -n "$(gcloud services vpc-peerings list \
      --project="${PROJECT_ID}" \
      --service=servicenetworking.googleapis.com \
      --network="${NETWORK}" \
      --format="value(peering)" 2>/dev/null || true)" ]]
}
if ! vpc_peering_exists; then
  echo "No VPC peering with servicenetworking.googleapis.com found on ${NETWORK}. Skipping."
else
  PEERING_ATTEMPTS=5
  for ATTEMPT in $(seq 1 "${PEERING_ATTEMPTS}"); do
    if delete_vpc_peering || ! vpc_peering_exists; then
      break
    fi
    if [[ ${ATTEMPT} -lt ${PEERING_ATTEMPTS} ]]; then
      echo "Attempt ${ATTEMPT} to delete the VPC peering failed. Retrying in 30 seconds..."
      sleep 30
    else
      echo "Warning: couldn't delete the VPC peering of ${NETWORK}." >&2
    fi
  done
fi

echo "[$(date)] ========== Deleting the Lustre private IP address range =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_ip_cleanup]
gcloud compute addresses delete "${LUSTRE_NAME}-range" \
    --project="${PROJECT_ID}" \
    --global \
    --quiet || true
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_ip_cleanup]

echo "[$(date)] ========== Deleting RDMA and GVNIC subnets =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_subnets_cleanup]
gcloud compute networks subnets delete "${GVNIC_NETWORK_PREFIX}-sub" \
    --project="${PROJECT_ID}" \
    --region="${CONTROL_PLANE_REGION}" \
    --quiet || true

for N in $(seq 0 7); do
  gcloud compute networks subnets delete "${RDMA_NETWORK_PREFIX}-sub-${N}" \
    --project="${PROJECT_ID}" \
    --region="${CONTROL_PLANE_REGION}" \
    --quiet || true &
done
wait
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_subnets_cleanup]

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_fwrules_and_network_cleanup]
echo "[$(date)] ========== Deleting firewall rules and networks =========="

NETWORKS=(
    "${RDMA_NETWORK_PREFIX}-net"
    "${GVNIC_NETWORK_PREFIX}-net"
    "${NETWORK}"
)

for NW in "${NETWORKS[@]}"; do

  # Skip if empty, named 'default', or not starting with a lowercase letter (invalid resource name)
  if [[ "${NW}" == "default" || ! "${NW}" =~ ^[a-z] ]]; then
    echo "Skipping protected/invalid network: '${NW}'"
    continue
  fi

  echo "========== Deleting firewall rules for ${NW} =========="
  for ATTEMPT in $(seq 1 10); do
    RULES=$(gcloud compute firewall-rules list \
      --project="${PROJECT_ID}" \
      --filter="network:${NW}" \
      --format="value(name)" || true)

    if [[ -z "${RULES}" ]]; then
      echo "No firewall rules remain for ${NW}"
      break
    fi

    echo "Attempt ${ATTEMPT}: deleting firewall rules for ${NW}..."
    for RULE in ${RULES}; do
      gcloud compute firewall-rules delete "${RULE}" --project="${PROJECT_ID}" --quiet || true
    done
    sleep 3
  done

  echo "[$(date)] ========== Deleting network ${NW} =========="
  gcloud compute networks delete "${NW}" --project="${PROJECT_ID}" --quiet || true
done
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_fwrules_and_network_cleanup]

echo "[$(date)] ========== Checking for leftover resources =========="
LEFTOVERS=0
if gcloud container clusters describe "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" --location="${CONTROL_PLANE_REGION}" > /dev/null 2>&1; then
  echo "Error: GKE cluster '${CLUSTER_NAME}' still exists." >&2
  LEFTOVERS=1
fi
if gcloud lustre instances describe "${LUSTRE_NAME}" \
    --project="${PROJECT_ID}" --location="${LUSTRE_ZONE}" > /dev/null 2>&1; then
  echo "Error: Managed Lustre instance '${LUSTRE_NAME}' still exists." >&2
  LEFTOVERS=1
fi
if gcloud compute addresses describe "${LUSTRE_NAME}-range" \
    --project="${PROJECT_ID}" --global > /dev/null 2>&1; then
  echo "Error: IP address range '${LUSTRE_NAME}-range' still exists." >&2
  LEFTOVERS=1
fi
for NW in "${NETWORKS[@]}"; do
  if [[ "${NW}" == "default" || ! "${NW}" =~ ^[a-z] ]]; then
    continue
  fi
  if gcloud compute networks describe "${NW}" \
      --project="${PROJECT_ID}" > /dev/null 2>&1; then
    echo "Error: VPC network '${NW}' still exists." >&2
    LEFTOVERS=1
  fi
done

echo "[$(date)] ========== Deleting local files =========="
rm -rf "${SCRIPT_DIR}/kubernetes-engine-samples" "${SCRIPT_DIR}/.tools" "${SCRIPT_DIR}/logs"

if [[ ${LEFTOVERS} -ne 0 ]]; then
  echo "[$(date)] ========== Cleanup finished with leftover resources =========="
  exit 1
fi
echo "[$(date)] ========== Cleanup Complete =========="
