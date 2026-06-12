#!/bin/bash
source 0_env.sh

set -e
set -x

# 1. IAM
declare -a ROLES=(
  "roles/compute.admin"
  "roles/storage.admin"
  "roles/iam.serviceAccountUser"
  "roles/artifactregistry.admin"
  "roles/cloudbuild.builds.editor"
  "roles/serviceusage.serviceUsageAdmin"
)

for i in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="user:${USER_EMAIL}" \
    --role="$i"
done

# 2. Create Cluster
# [START hypercomputer_gpu_tune_gemma3_gke_create_cluster]
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${CLUSTER_REGION}" \
    --release-channel=rapid
# [END hypercomputer_gpu_tune_gemma3_gke_create_cluster]

# 3. Get Creds
# [START hypercomputer_gpu_tune_gemma3_gke_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${CLUSTER_REGION}"
# [END hypercomputer_gpu_tune_gemma3_gke_get_creds]

# 4. Create HF Secret
# [START hypercomputer_gpu_tune_gemma3_gke_create_secret]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_create_secret]

# 5. Create Artifact Registry
# [START hypercomputer_gpu_tune_gemma3_gke_create_registry]
gcloud artifacts repositories create gemma \
    --repository-format=docker \
    --location="${CLUSTER_REGION}" \
    --description="Repository for Gemma fine tuning workload containers" || true
# [END hypercomputer_gpu_tune_gemma3_gke_create_registry]
