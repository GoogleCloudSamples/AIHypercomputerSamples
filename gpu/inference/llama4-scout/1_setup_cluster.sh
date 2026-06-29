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

# 1. Create Cluster
echo "[$(date)] ==================== Creating Cluster... ===================="
# [START hypercomputer_gpu_infer_llama4scout_create_cluster]
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --release-channel=rapid \
    --network="${NETWORK}" \
    --subnetwork="${SUBNETWORK}"
# [END hypercomputer_gpu_infer_llama4scout_create_cluster]
echo "[$(date)] ==================== Cluster created. ===================="

echo "[$(date)] ==================== Verifying cluster status... ===================="
STATUS=$(gcloud container clusters describe $CLUSTER_NAME --region $REGION --format="value(status)")
if [ "$STATUS" = "RUNNING" ]; then
    echo "[$(date)] ==================== Success! Cluster $CLUSTER_NAME is RUNNING and ready for deployment. ===================="
else
    echo "[$(date)] ==================== Warning: Cluster is in '$STATUS' state.===================="
    exit 1
fi

# 2. Get Creds
echo "[$(date)] ==================== Getting the credentials. ===================="
# [START hypercomputer_gpu_infer_llama4scout_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}"
# [END hypercomputer_gpu_infer_llama4scout_get_creds]
echo "[$(date)] ==================== Credentials got. ===================="

# 3. Create HF Secret
echo "[$(date)] ==================== Creating the HF secret. ===================="
# [START hypercomputer_gpu_infer_llama4scout_create_secret]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_llama4scout_create_secret]
echo "[$(date)] ==================== Secret created. ===================="

echo "[$(date)] ==================== Stabilizing API and Networking (300s) ===================="
sleep 300
