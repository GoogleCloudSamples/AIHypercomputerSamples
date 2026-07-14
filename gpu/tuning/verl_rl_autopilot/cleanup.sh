#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source 0_env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Starting Cleanup ==="

echo "Deleting Ray Cluster (if exists)..."
# [START hypercomputer_gpu_train_ray_verl_auto_delete_ray]
if [ -f "${SCRIPT_DIR}/ray-cluster-auto-dranet.yaml" ]; then
  envsubst < "${SCRIPT_DIR}/ray-cluster-auto-dranet.yaml" | kubectl delete -f - --ignore-not-found=true || true
fi
# [END hypercomputer_gpu_train_ray_verl_auto_delete_ray]

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
# [START hypercomputer_gpu_train_ray_verl_auto_delete_bucket]
if gcloud storage buckets describe gs://${GS_BUCKET} >/dev/null 2>&1; then
  gcloud storage rm "gs://${GS_BUCKET}/**"
  gcloud storage buckets delete gs://${GS_BUCKET} --quiet || true
fi
# [END hypercomputer_gpu_train_ray_verl_auto_delete_bucket]

echo "Deleting GKE Cluster ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_train_ray_verl_auto_delete_cluster]
gcloud container clusters delete ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --quiet || true
# [END hypercomputer_gpu_train_ray_verl_auto_delete_cluster]

echo "Deleting local files and directories..."
rm -rf "${SCRIPT_DIR}/kubernetes-engine-samples"
rm -rf "${SCRIPT_DIR}/env"

echo "=== Cleanup Complete ==="

