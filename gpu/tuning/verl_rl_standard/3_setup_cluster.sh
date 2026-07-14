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

set -euo pipefail

source 0_env.sh

# Create GKE Standard Cluster
if ! gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating GKE Standard cluster ${CLUSTER_NAME}..."
  # [START hypercomputer_gpu_train_ray_verl_std_create_cluster]
  gcloud container clusters create ${CLUSTER_NAME} \
      --location=${CONTROL_PLANE_REGION} \
      --enable-dataplane-v2 \
      --workload-pool=${PROJECT_ID}.svc.id.goog \
      --enable-ip-alias \
      --enable-multi-networking \
      --addons=RayOperator,GcsFuseCsiDriver \
      --machine-type=c2-standard-16 \
      --num-nodes=1 \
      --min-nodes=1 \
      --max-nodes=5 \
      --enable-autoscaling \
      --project=${PROJECT_ID}
  # [END hypercomputer_gpu_train_ray_verl_std_create_cluster]
else
  echo "Cluster ${CLUSTER_NAME} already exists."
fi

# Get credentials
echo "Getting credentials for cluster ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_train_ray_verl_std_get_creds]
gcloud container clusters get-credentials ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --project=${PROJECT_ID}
# [END hypercomputer_gpu_train_ray_verl_std_get_creds]

# Create GPU Node Pool
if ! gcloud container node-pools describe gpu-pool --cluster=${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating GPU node pool gpu-pool..."
  
  # Build the gcloud command. We need to handle reservation if it is set.
  # [START hypercomputer_gpu_train_ray_verl_std_create_nodepool]
  CMD=(
    gcloud container node-pools create gpu-pool
    --cluster="${CLUSTER_NAME}"
    --location="${CONTROL_PLANE_REGION}"
    --node-locations="${NODE_ZONE}"
    --machine-type="${MACHINE_TYPE}"
    --accelerator="type=${GPU_TYPE},count=8,gpu-driver-version=DEFAULT"
    --enable-autoscaling
    --num-nodes=2
    --total-max-nodes=10
    --additional-node-network="network=${GVNIC_NETWORK_PREFIX}-net,subnetwork=${GVNIC_NETWORK_PREFIX}-sub"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-0"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-1"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-2"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-3"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-4"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-5"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-6"
    --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-7"
    --project="${PROJECT_ID}"
  )

  if [ -n "${RESERVATION:-}" ]; then
    CMD+=("--reservation-affinity=specific" "--reservation=${RESERVATION}")
  else
    CMD+=("--reservation-affinity=none")
  fi

  "${CMD[@]}"
  # [END hypercomputer_gpu_train_ray_verl_std_create_nodepool]
else
  echo "Node pool gpu-pool already exists."
fi

# Install NCCL RDMA installer
echo "Installing NCCL RDMA installer..."
# [START hypercomputer_gpu_train_ray_verl_std_install_nccl]
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/refs/heads/master/gpudirect-rdma/nccl-rdma-installer.yaml
# [END hypercomputer_gpu_train_ray_verl_std_install_nccl]

echo "Cluster setup complete."

