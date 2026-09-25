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
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_ip_range_create]
gcloud compute addresses create ${LUSTRE_NAME}-range \
    --global --purpose=VPC_PEERING \
    --prefix-length=20 --network=${NETWORK}
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_ip_range_create]

echo "[$(date)] ========== Creating VPC peering connection... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_connect_vpc_peering]
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=${LUSTRE_NAME}-range \
    --network=${NETWORK}
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_connect_vpc_peering]

echo "[$(date)] ========== Creating a Managed Lustre instance... =========="
create_lustre_instance() {
    # [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_create]
    gcloud lustre instances create ${LUSTRE_NAME} \
        --per-unit-storage-throughput=500 \
        --capacity-gib=18000 \
        --filesystem=lustrefs \
        --location=${LUSTRE_ZONE} \
        --network=projects/${PROJECT_ID}/global/networks/${NETWORK} \
        --gke-support-enabled
    # [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_create]
}

if ! create_lustre_instance; then
    echo "Failed to create Lustre instance in ${LUSTRE_ZONE}. Trying other zones in ${CONTROL_PLANE_REGION}..."
    AVAILABLE_ZONES=$(gcloud compute zones list \
        --filter="region:(${CONTROL_PLANE_REGION}) AND status=UP AND name!=${LUSTRE_ZONE}" \
        --format="value(name)")
    LUSTRE_CREATED=false
    for ZONE in ${AVAILABLE_ZONES}; do
        export LUSTRE_ZONE="${ZONE}"
        echo "Retrying Lustre instance creation in ${LUSTRE_ZONE}..."
        if create_lustre_instance; then
            echo "Successfully created Lustre instance in ${LUSTRE_ZONE}."
            LUSTRE_CREATED=true
            break
        fi
    done
    if [[ "${LUSTRE_CREATED}" != "true" ]]; then
        echo "Error: Failed to create Lustre instance in any zone in ${CONTROL_PLANE_REGION}." >&2
        exit 1
    fi
fi

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_ip_export]
export LUSTRE_IP=$(gcloud lustre instances describe ${LUSTRE_NAME} \
    --location=${LUSTRE_ZONE} --format="value(mountPoint)" | awk -F'@' '{print $1}')
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_ip_export]

echo "[$(date)] ========== Creating a Persistent Volume for Lustre... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_pv_create]
envsubst < lustre-pv.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_pv_create]

echo "[$(date)] ========== Creating a Persistent Volume Claim for Lustre... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_pvc_create]
kubectl apply -f lustre-pvc.yaml
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_pvc_create]