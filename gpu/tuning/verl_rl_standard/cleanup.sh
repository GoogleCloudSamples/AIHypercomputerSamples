#!/bin/bash

# Copyright 2026 Google LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

source 0_env.sh

echo "=== Starting Cleanup ==="

# 1. Delete Ray Cluster
echo "Deleting Ray Cluster (if exists)..."
if [ -f "${SCRIPT_DIR}/ray-cluster-standard.yaml" ]; then
  # We need to make sure we have credentials to run kubectl
  if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID}
    envsubst < "${SCRIPT_DIR}/ray-cluster-standard.yaml" | kubectl delete -f - --ignore-not-found=true || true
  fi
fi

# 2. Delete GCS FUSE Storage
echo "Deleting GCS FUSE Storage..."
if [ -f "${SCRIPT_DIR}/gcsfuse-storage.yaml" ]; then
  if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    envsubst < "${SCRIPT_DIR}/gcsfuse-storage.yaml" | kubectl delete -f - --ignore-not-found=true || true
  fi
fi

# 3. Delete secrets and service accounts
echo "Deleting secrets and service accounts..."
if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  kubectl delete secret hf-secret -n ${NAMESPACE} --ignore-not-found=true || true
  kubectl delete serviceaccount ${KSA_NAME} -n ${NAMESPACE} --ignore-not-found=true || true
fi

# 4. Delete GCS Bucket
echo "Deleting GCS Bucket gs://${GS_BUCKET}..."
if gcloud storage buckets describe gs://${GS_BUCKET} --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage rm -r "gs://${GS_BUCKET}" --project="${PROJECT_ID}" || true
fi

# 5. Delete GKE Cluster
echo "Deleting GKE Cluster ${CLUSTER_NAME}..."
if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  gcloud container clusters delete ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet || true
fi

# 6. Delete VPC Networks and Subnets
echo "Deleting VPC Networks and Subnets..."

# Delete RDMA subnets first
echo "Deleting RDMA subnets..."
for N in $(seq 0 7); do
  if gcloud compute networks subnets describe ${RDMA_NETWORK_PREFIX}-sub-$N --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    gcloud compute networks subnets delete ${RDMA_NETWORK_PREFIX}-sub-$N --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet &
  fi
done
wait

# Delete RDMA network
if gcloud compute networks describe ${RDMA_NETWORK_PREFIX}-net --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting RDMA network ${RDMA_NETWORK_PREFIX}-net..."
  gcloud compute networks delete ${RDMA_NETWORK_PREFIX}-net --project=${PROJECT_ID} --quiet || true
fi

# Delete GVNIC Firewall
if gcloud compute firewall-rules describe ${GVNIC_NETWORK_PREFIX}-internal --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting firewall rule ${GVNIC_NETWORK_PREFIX}-internal..."
  gcloud compute firewall-rules delete ${GVNIC_NETWORK_PREFIX}-internal --project=${PROJECT_ID} --quiet || true
fi

# Delete GVNIC subnet
if gcloud compute networks subnets describe ${GVNIC_NETWORK_PREFIX}-sub --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting GVNIC subnet ${GVNIC_NETWORK_PREFIX}-sub..."
  gcloud compute networks subnets delete ${GVNIC_NETWORK_PREFIX}-sub --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet || true
fi

# Delete GVNIC network
if gcloud compute networks describe ${GVNIC_NETWORK_PREFIX}-net --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting GVNIC network ${GVNIC_NETWORK_PREFIX}-net..."
  gcloud compute networks delete ${GVNIC_NETWORK_PREFIX}-net --project=${PROJECT_ID} --quiet || true
fi

# 7. Delete local files
echo "Deleting local files and directories..."
rm -rf "${SCRIPT_DIR}/kubernetes-engine-samples"
rm -rf "${SCRIPT_DIR}/env"
rm -f "${SCRIPT_DIR}/runtime-env-local.yaml"

echo "=== Cleanup Complete ==="
