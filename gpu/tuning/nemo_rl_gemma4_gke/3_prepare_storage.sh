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

echo "[$(date)] ========== Creating reserved IP range for Lustre... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_ip_range_create]
gcloud compute addresses create "${LUSTRE_NAME}-range" \
    --project="${PROJECT_ID}" \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=20 \
    --network="${NETWORK}"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_ip_range_create]

echo "[$(date)] ========== Creating VPC peering connection... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_connect_vpc_peering]
gcloud services vpc-peerings connect \
    --project="${PROJECT_ID}" \
    --service=servicenetworking.googleapis.com \
    --ranges="${LUSTRE_NAME}-range" \
    --network="${NETWORK}"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_connect_vpc_peering]

echo "[$(date)] ========== Checking Managed Lustre quota in ${LUSTRE_ZONE}... =========="
LUSTRE_CAPACITY_QUOTA="$(gcloud quotas info list \
    --service=lustre.googleapis.com \
    --project="${PROJECT_ID}" \
    --flatten="dimensionsInfos[]" \
    --filter="quotaId=Capacity AND dimensionsInfos.applicableLocations=${LUSTRE_ZONE}" \
    --format="value(dimensionsInfos.details.value)" | head -n 1 || true)"

if [[ ! "${LUSTRE_CAPACITY_QUOTA}" =~ ^[0-9]+$ ]]; then
    echo "Warning: Could not read the Managed Lustre capacity quota in ${LUSTRE_ZONE}. Continuing." >&2
elif [[ "${LUSTRE_CAPACITY_QUOTA}" -lt 18000 ]]; then
    echo "Warning: Managed Lustre capacity quota in ${LUSTRE_ZONE} is ${LUSTRE_CAPACITY_QUOTA} GiB, but 18000 GiB is required. The instance creation is likely to fail." >&2
fi

echo "[$(date)] ========== Creating a Managed Lustre instance... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_create]
gcloud lustre instances create "${LUSTRE_NAME}" \
    --project="${PROJECT_ID}" \
    --per-unit-storage-throughput=500 \
    --capacity-gib=18000 \
    --filesystem=lustrefs \
    --location="${LUSTRE_ZONE}" \
    --network="projects/${PROJECT_ID}/global/networks/${NETWORK}" \
    --gke-support-enabled
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_create]

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_ip_export]
LUSTRE_IP="$(gcloud lustre instances describe "${LUSTRE_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${LUSTRE_ZONE}" \
    --format="value(mountPoint)" | awk -F'@' '{print $1}')"
export LUSTRE_IP
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_ip_export]

if [[ -z "${LUSTRE_IP}" ]]; then
    echo "Error: Could not read the mount point IP address of Lustre instance ${LUSTRE_NAME}." >&2
    exit 1
fi
echo "Lustre instance ${LUSTRE_NAME} is reachable at ${LUSTRE_IP}."

echo "[$(date)] ========== Creating a Persistent Volume for Lustre... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_pv_create]
envsubst < lustre-pv.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_pv_create]

echo "[$(date)] ========== Creating a Persistent Volume Claim for Lustre... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_pvc_create]
kubectl apply -f lustre-pvc.yaml
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_lustre_pvc_create]

echo "[$(date)] Waiting for lustre-pvc to be Bound..."
if ! kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/lustre-pvc --timeout=300s; then
    echo "Error: lustre-pvc did not become Bound." >&2
    kubectl describe pv lustre-pv || true
    kubectl describe pvc lustre-pvc || true
    exit 1
fi
