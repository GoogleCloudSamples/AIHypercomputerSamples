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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [ -f "0_env.sh" ]; then
  source 0_env.sh 2>/dev/null || true
fi

echo "=== Starting Cleanup ==="

echo "Deleting Ray Cluster (if exists)..."
if [ -f "${SCRIPT_DIR}/ray-cluster-auto-dranet.yaml" ]; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_ray]
  envsubst < "${SCRIPT_DIR}/ray-cluster-auto-dranet.yaml" | kubectl delete -f - --ignore-not-found=true || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_ray]
fi

echo "Deleting Data Preparation Job (if exists)..."
kubectl delete job data-prep-job -n "${NAMESPACE:-default}" --ignore-not-found=true || true

echo "Deleting GCS FUSE Storage..."
if [ -f "${SCRIPT_DIR}/gcsfuse-storage.yaml" ]; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_gcsfuse]
  envsubst < "${SCRIPT_DIR}/gcsfuse-storage.yaml" | kubectl delete -f - --ignore-not-found=true || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_gcsfuse]
fi

echo "Deleting secrets and service accounts..."
kubectl delete secret hf-secret -n "${NAMESPACE:-default}" --ignore-not-found=true || true
kubectl delete serviceaccount "${KSA_NAME:-}" -n "${NAMESPACE:-default}" --ignore-not-found=true || true

echo "Deleting DRANET resources..."
# [START hypercomputer_gpu_train_ray_verl_auto_delete_dranet]
if [ -f "${SCRIPT_DIR}/resourceclaim-dranet.yaml" ]; then
  kubectl delete -f "${SCRIPT_DIR}/resourceclaim-dranet.yaml" --ignore-not-found=true || true
fi
if [ -f "${SCRIPT_DIR}/computeclass-dranet.yaml" ]; then
  kubectl delete -f "${SCRIPT_DIR}/computeclass-dranet.yaml" --ignore-not-found=true || true
fi
# [END hypercomputer_gpu_train_ray_verl_auto_delete_dranet]

echo "Deleting GCS Bucket gs://${GS_BUCKET}..."
if [ -n "${GS_BUCKET:-}" ] && gcloud storage buckets describe "gs://${GS_BUCKET}" >/dev/null 2>&1; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_bucket]
  gcloud storage rm -r "gs://${GS_BUCKET}" --project="${PROJECT_ID:-$(gcloud config get project)}" --quiet || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_bucket]
fi

# Retrieve cluster hash before deleting the cluster
echo "Retrieving cluster hash before deletion..."
if [ -n "${CLUSTER_NAME:-}" ] && [ -n "${CONTROL_PLANE_REGION:-}" ]; then
  if POD_RANGE=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${CONTROL_PLANE_REGION}" --format="value(ipAllocationPolicy.clusterSecondaryRangeName)" 2>/dev/null); then
    export HASH=${POD_RANGE##*-}
    echo "Saved cluster hash: ${HASH}"
  else
    echo "Warning: Could not retrieve cluster hash. Network cleanup might fail if cluster is already deleted."
  fi
fi

echo "Deleting GKE Cluster ${CLUSTER_NAME}..."
if [ -n "${CLUSTER_NAME:-}" ] && [ -n "${CONTROL_PLANE_REGION:-}" ]; then
  # [START hypercomputer_gpu_train_ray_verl_auto_delete_cluster]
  gcloud container clusters delete "${CLUSTER_NAME}" --location="${CONTROL_PLANE_REGION}" --quiet || true
  # [END hypercomputer_gpu_train_ray_verl_auto_delete_cluster]
fi

# Run network cleanup after GKE cluster is deleted (so subnets are not in use)
if [ -f "${SCRIPT_DIR}/cleanup_networks.sh" ]; then
  "${SCRIPT_DIR}/cleanup_networks.sh" || true
fi

echo "Deleting local files and directories..."
rm -rf "${SCRIPT_DIR}/env"

echo "=== Cleanup Complete ==="
