#!/bin/bash

source 0_env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Starting Cleanup ==="

echo "Deleting Ray Cluster (if exists)..."
if [ -f "${SCRIPT_DIR}/ray-cluster-auto-dranet.yaml" ]; then
  envsubst < "${SCRIPT_DIR}/ray-cluster-auto-dranet.yaml" | kubectl delete -f - --ignore-not-found=true || true
fi

echo "Deleting GCS FUSE Storage..."
if [ -f "${SCRIPT_DIR}/gcsfuse-storage.yaml" ]; then
  envsubst < "${SCRIPT_DIR}/gcsfuse-storage.yaml" | kubectl delete -f - --ignore-not-found=true || true
fi

echo "Deleting secrets and service accounts..."
kubectl delete secret hf-secret -n ${NAMESPACE} --ignore-not-found=true || true
kubectl delete serviceaccount ${KSA_NAME} -n ${NAMESPACE} --ignore-not-found=true || true

echo "Deleting DRANET resources..."
kubectl delete -f "${SCRIPT_DIR}/resourceclaim-dranet.yaml" --ignore-not-found=true || true
if [ -f "${SCRIPT_DIR}/computeclass-dranet.yaml" ]; then
  kubectl delete -f "${SCRIPT_DIR}/computeclass-dranet.yaml" --ignore-not-found=true || true
fi

echo "Deleting GCS Bucket gs://${GS_BUCKET}..."
if gcloud storage buckets describe gs://${GS_BUCKET} >/dev/null 2>&1; then
  gcloud storage rm "gs://${GS_BUCKET}/**"
  gcloud storage buckets delete gs://${GS_BUCKET} --quiet || true
fi

echo "Deleting GKE Cluster ${CLUSTER_NAME}..."
gcloud container clusters delete ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --quiet || true

echo "Deleting local files and directories..."
rm -rf "${SCRIPT_DIR}/kubernetes-engine-samples"
rm -rf "${SCRIPT_DIR}/env"

echo "=== Cleanup Complete ==="
