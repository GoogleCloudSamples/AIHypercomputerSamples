#!/bin/bash

set -euo pipefail

source 0_env.sh

# Create GCS Bucket if it doesn't exist
if ! gcloud storage buckets describe "gs://${GS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Creating bucket gs://${GS_BUCKET}..."
  gcloud storage buckets create "gs://${GS_BUCKET}" \
    --location="${CONTROL_PLANE_REGION}" \
    --project="${PROJECT_ID}" \
    --enable-hierarchical-namespace \
    --uniform-bucket-level-access
else
  echo "Bucket gs://${GS_BUCKET} already exists."
fi

# Create KSA if it doesn't exist
if ! kubectl get serviceaccount ${KSA_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "Creating Kubernetes Service Account ${KSA_NAME} in namespace ${NAMESPACE}..."
  kubectl create serviceaccount ${KSA_NAME} -n ${NAMESPACE}
fi

# Bind KSA to the bucket using Workload Identity (direct binding)
echo "Binding KSA ${KSA_NAME} to bucket gs://${GS_BUCKET}..."
gcloud storage buckets add-iam-policy-binding "gs://${GS_BUCKET}" \
    --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA_NAME}" \
    --role="roles/storage.objectUser" \
    --project="${PROJECT_ID}"

# Create Hugging Face Token
if kubectl get secret hf-secret -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "Secret hf-secret already exists. Deleting it..."
  kubectl delete secret hf-secret -n ${NAMESPACE}
fi
kubectl create secret generic hf-secret --from-literal=hf_token=${HF_TOKEN} -n ${NAMESPACE}

# Create GCS fuse PV and PVC
echo "Creating GCS fuse PV and PVC..."
# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsubst < "${SCRIPT_DIR}/gcsfuse-storage.yaml" | kubectl apply -f -

echo "Storage setup complete. Bucket: gs://${GS_BUCKET}"
