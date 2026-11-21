#!/bin/bash
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

SA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# 1. Create GKE Cluster in Autopilot
# [START hypercomputer_gpu_tune_gemma4_ray_create_cluster]
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --enable-ray-operator \
    --enable-ray-cluster-monitoring \
    --enable-ray-cluster-logging
# [END hypercomputer_gpu_tune_gemma4_ray_create_cluster]

echo "Waiting for cluster '${CLUSTER_NAME}' to reach the RUNNING state..."
TIMEOUT_SECONDS=1800
INTERVAL_SECONDS=30
ELAPSED_SECONDS=0
while true; do
    CURRENT_STATUS="$(gcloud container clusters describe "${CLUSTER_NAME}" \
        --project="${PROJECT_ID}" --location="${REGION}" \
        --format="value(status)")"
    echo "Cluster status: '${CURRENT_STATUS}' (${ELAPSED_SECONDS}/${TIMEOUT_SECONDS}s elapsed)"
    if [[ "${CURRENT_STATUS}" == "RUNNING" ]]; then
        break
    fi
    if [[ "${CURRENT_STATUS}" == "ERROR" ]]; then
        echo "Error: Cluster '${CLUSTER_NAME}' is in the ERROR state."
        exit 1
    fi
    if [[ "${ELAPSED_SECONDS}" -ge "${TIMEOUT_SECONDS}" ]]; then
        echo "Error: Cluster did not reach the RUNNING state within ${TIMEOUT_SECONDS}s."
        exit 1
    fi
    sleep "${INTERVAL_SECONDS}"
    ELAPSED_SECONDS=$((ELAPSED_SECONDS + INTERVAL_SECONDS))
done

# 2. Get credentials
# [START hypercomputer_gpu_tune_gemma4_ray_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_gpu_tune_gemma4_ray_get_creds]

# 3. Create HF Secret
# [START hypercomputer_gpu_tune_gemma4_ray_create_secret]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_ray_create_secret]

# 4. Create Cloud Storage bucket
# [START hypercomputer_gpu_tune_gemma4_ray_create_gcs_bucket]
gcloud storage buckets create "gs://${GCS_BUCKET}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_gpu_tune_gemma4_ray_create_gcs_bucket]

echo "Verifying bucket creation..."
if gcloud storage buckets describe "gs://${GCS_BUCKET}" \
    --project="${PROJECT_ID}" > /dev/null 2>&1; then
    echo "Bucket gs://${GCS_BUCKET} is created and accessible."
else
    echo "Error: Bucket gs://${GCS_BUCKET} could not be found or is inaccessible."
    exit 1
fi

# 5. Create IAM service account
# [START hypercomputer_gpu_tune_gemma4_ray_create_gsa_account]
gcloud iam service-accounts create "${GSA_NAME}" \
    --project="${PROJECT_ID}" \
    --description="Account for Ray to save Gemma 4 training results" \
    --display-name="Ray Gemma 4 Training SA"
# [END hypercomputer_gpu_tune_gemma4_ray_create_gsa_account]

echo "Waiting for the IAM service account to replicate..."
MAX_IAM_ATTEMPTS=24
IAM_ATTEMPT=1
until gcloud iam service-accounts describe "${SA_EMAIL}" \
    --project="${PROJECT_ID}" > /dev/null 2>&1; do
    if [[ "${IAM_ATTEMPT}" -ge "${MAX_IAM_ATTEMPTS}" ]]; then
        echo "Error: The IAM service account did not replicate within the allotted time."
        exit 1
    fi
    echo "Service account not ready (attempt ${IAM_ATTEMPT}/${MAX_IAM_ATTEMPTS}). Waiting 5 seconds..."
    sleep 5
    IAM_ATTEMPT=$((IAM_ATTEMPT + 1))
done
echo "Service account is ready. Waiting 15 seconds for Cloud Storage synchronization..."
sleep 15

# 6. Add Storage Admin role to GSA on the bucket
# [START hypercomputer_gpu_tune_gemma4_ray_storage_admin_role]
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --project="${PROJECT_ID}" \
    --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.admin"
# [END hypercomputer_gpu_tune_gemma4_ray_storage_admin_role]

# 7. Create Kubernetes Service Account
# [START hypercomputer_gpu_tune_gemma4_ray_create_sa_account]
kubectl create serviceaccount "${RAY_SA}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_ray_create_sa_account]

# 8. Bind KSA and GSA via Workload Identity
# [START hypercomputer_gpu_tune_gemma4_ray_wi]
gcloud iam service-accounts add-iam-policy-binding \
    "${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[default/${RAY_SA}]"
# [END hypercomputer_gpu_tune_gemma4_ray_wi]

# 9. Annotate Kubernetes Service Account
# [START hypercomputer_gpu_tune_gemma4_ray_asa]
kubectl annotate serviceaccount "${RAY_SA}" \
    "iam.gke.io/gcp-service-account=${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --overwrite
# [END hypercomputer_gpu_tune_gemma4_ray_asa]

# 10. Wait for Workload Identity replication
# [START hypercomputer_gpu_tune_gemma4_ray_rc]
echo "Waiting 30 seconds for Workload Identity IAM replication..."
sleep 30
# [END hypercomputer_gpu_tune_gemma4_ray_rc]
