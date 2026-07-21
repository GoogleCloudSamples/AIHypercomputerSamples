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

echo "=== Starting Cleanup ==="

echo "Deleting Ray Cluster (if exists)..."
if [ -f "ray-cluster-auto-dranet.yaml" ]; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_ray]
  envsubst < ray-cluster-auto-dranet.yaml | kubectl delete -f - --ignore-not-found=true || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_ray]
fi

echo "Deleting GCS FUSE Storage..."
if [ -f "${SCRIPT_DIR}/gcsfuse-storage.yaml" ]; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_gcsfuse]
  envsubst < gcsfuse-storage.yaml | kubectl delete -f - --ignore-not-found=true || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_gcsfuse]
fi

echo "Deleting secrets and service accounts..."
kubectl delete secret hf-secret -n ${NAMESPACE} --ignore-not-found=true || true
kubectl delete serviceaccount ${KSA_NAME} -n ${NAMESPACE} --ignore-not-found=true || true

echo "Deleting DRANET resources..."
# [START hypercomputer_gpu_train_ray_verl_auto_delete_dranet]
kubectl delete -f "resourceclaim-dranet.yaml" --ignore-not-found=true || true
kubectl delete -f "computeclass-dranet.yaml" --ignore-not-found=true || true
# [END hypercomputer_gpu_train_ray_verl_auto_delete_dranet]

echo "Deleting GCS Bucket gs://${GS_BUCKET}..."
if gcloud storage buckets describe gs://${GS_BUCKET} >/dev/null 2>&1; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_bucket]
  gcloud storage rm -r "gs://${GS_BUCKET}" || true
  gcloud storage buckets delete gs://${GS_BUCKET} --quiet || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_bucket]
fi

echo "Deleting GKE Cluster ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_train_ray_verl_auto_delete_cluster]
gcloud container clusters delete ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --quiet || true
# [END hypercomputer_gpu_train_ray_verl_auto_delete_cluster]

echo "Deleting local files and directories..."
rm -rf "${SCRIPT_DIR}/env"

echo "=== Cleanup Complete ==="

