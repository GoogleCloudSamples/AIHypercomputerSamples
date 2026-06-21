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
# [START hypercomputer_gpu_tune_gemma3_gke_create_cluster]
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${CLUSTER_REGION}" \
    --release-channel=rapid
# [END hypercomputer_gpu_tune_gemma3_gke_create_cluster]
echo "[$(date)] ==================== Cluster created. ===================="

# 2. Get Creds
# [START hypercomputer_gpu_tune_gemma3_gke_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${CLUSTER_REGION}"
# [END hypercomputer_gpu_tune_gemma3_gke_get_creds]
echo "[$(date)] ==================== Credentials got. ===================="

# 3. Create HF Secret
# [START hypercomputer_gpu_tune_gemma3_gke_create_secret]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_create_secret]
echo "[$(date)] ==================== Secret created. ===================="

# 4. Create Artifact Registry
# [START hypercomputer_gpu_tune_gemma3_gke_create_repo]
gcloud artifacts repositories create gemma \
    --repository-format=docker \
    --location="${ARTIFACT_REPO_LOCATION}" \
    --description="Repository for Gemma fine tuning workload containers" || true
# [END hypercomputer_gpu_tune_gemma3_gke_create_repo]
echo "[$(date)] ==================== Artifact Registry Repository created. ===================="
