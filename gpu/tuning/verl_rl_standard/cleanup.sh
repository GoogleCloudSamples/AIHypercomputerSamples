#!/bin/bash
#
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

# 1. Delete Ray Cluster & Force remove finalizers if stuck
echo "Deleting Ray Cluster (if exists)..."
if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet || true

  if [ -f "${SCRIPT_DIR}/ray-cluster-standard.yaml" ]; then
    # Timeout 30s for graceful deletion, then remove finalizers if stuck
    envsubst < "${SCRIPT_DIR}/ray-cluster-standard.yaml" | kubectl delete --timeout=30s -f - --ignore-not-found=true || true
  fi

  # Force remove finalizers on any remaining rayclusters to prevent hanging GKE deletion
  kubectl get raycluster -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | xargs -r -I {} kubectl patch raycluster {} -n ${NAMESPACE} -p '{"metadata":{"finalizers":null}}' --type=merge || true
fi

# 2. Delete GCS FUSE Storage
echo "Deleting GCS FUSE Storage..."
if [ -f "${SCRIPT_DIR}/gcsfuse-storage.yaml" ]; then
  if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    envsubst < "${SCRIPT_DIR}/gcsfuse-storage.yaml" | kubectl delete --timeout=30s -f - --ignore-not-found=true || true
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
if gcloud storage buckets describe "gs://${GS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage rm -r "gs://${GS_BUCKET}" --project="${PROJECT_ID}" || true
fi

# 5. Delete GKE Cluster and Wait for Managed Instance Groups to vanish
echo "Deleting GKE Cluster ${CLUSTER_NAME}..."
if gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  gcloud container clusters delete ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet || true
fi

# Emergency fallback: Delete orphaned GKE Instance Groups if cluster delete missed any
echo "Checking for remaining GKE Instance Groups..."
for mig in $(gcloud compute instance-groups managed list --project=${PROJECT_ID} --filter="name ~ ${CLUSTER_NAME}" --format="value(name)" 2>/dev/null); do
  zone=$(gcloud compute instance-groups managed list --project=${PROJECT_ID} --filter="name=${mig}" --format="value(zone.basename())" 2>/dev/null)
  echo "Force deleting orphaned instance group: ${mig} in zone ${zone}"
  gcloud compute instance-groups managed delete ${mig} --zone=${zone} --project=${PROJECT_ID} --quiet || true
done

# 6. Delete VPC Networks and Subnets
echo "Deleting VPC Networks and Subnets..."

# Function to safely delete all firewall rules for a given network
Delete_Network_Firewalls() {
  local NET_NAME=$1
  echo "Deleting all firewall rules associated with network ${NET_NAME}..."
  for rule in $(gcloud compute firewall-rules list --filter="network:${NET_NAME}" --format="value(name)" --project=${PROJECT_ID} 2>/dev/null); do
    echo "Deleting firewall rule ${rule}..."
    gcloud compute firewall-rules delete ${rule} --project=${PROJECT_ID} --quiet || true
  done
}

# Delete Firewalls for both networks first
Delete_Network_Firewalls "${RDMA_NETWORK_PREFIX}-net"
Delete_Network_Firewalls "${GVNIC_NETWORK_PREFIX}-net"

# Delete RDMA subnets synchronously with retries
echo "Deleting RDMA subnets..."
for N in $(seq 0 7); do
  if gcloud compute networks subnets describe ${RDMA_NETWORK_PREFIX}-sub-$N --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    echo "Deleting subnet ${RDMA_NETWORK_PREFIX}-sub-$N..."
    gcloud compute networks subnets delete ${RDMA_NETWORK_PREFIX}-sub-$N --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet || true
  fi
done

# Delete GVNIC subnet
if gcloud compute networks subnets describe ${GVNIC_NETWORK_PREFIX}-sub --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting GVNIC subnet ${GVNIC_NETWORK_PREFIX}-sub..."
  gcloud compute networks subnets delete ${GVNIC_NETWORK_PREFIX}-sub --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} --quiet || true
fi

# Delete Networks
if gcloud compute networks describe ${RDMA_NETWORK_PREFIX}-net --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting RDMA network ${RDMA_NETWORK_PREFIX}-net..."
  gcloud compute networks delete ${RDMA_NETWORK_PREFIX}-net --project=${PROJECT_ID} --quiet || true
fi

if gcloud compute networks describe ${GVNIC_NETWORK_PREFIX}-net --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Deleting GVNIC network ${GVNIC_NETWORK_PREFIX}-net..."
  gcloud compute networks delete ${GVNIC_NETWORK_PREFIX}-net --project=${PROJECT_ID} --quiet || true
fi

echo "=== Cleanup Complete ==="
