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
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --release-channel=rapid

# 3. Get Creds
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}"

# 4. Create HF Secret
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

# 5. Create Artifact Registry
gcloud artifacts repositories create gemma \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Repository for Gemma fine tuning workload containers" || true
