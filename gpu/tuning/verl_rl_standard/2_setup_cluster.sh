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

# Create GKE Standard Cluster
if ! gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating GKE Standard cluster ${CLUSTER_NAME}..."

  if [[ "${CPU_MACHINE_TYPE:-YOUR_CPU_MACHINE_TYPE}" == "YOUR_CPU_MACHINE_TYPE" ]]; then
    CPU_MACHINE_TYPE="n2-standard-16"
  fi

  # [START hypercomputer_gpu_train_ray_verl_std_create_cluster]
  gcloud container clusters create ${CLUSTER_NAME} \
      --location=${CONTROL_PLANE_REGION} \
      --node-locations=${NODE_ZONE} \
      --enable-dataplane-v2 \
      --workload-pool=${PROJECT_ID}.svc.id.goog \
      --enable-ip-alias \
      --enable-multi-networking \
      --addons=RayOperator,GcsFuseCsiDriver \
      --machine-type=${CPU_MACHINE_TYPE} \
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

  if [[ "${NODEPOOL_TIMEOUT:-YOUR_NODEPOOL_TIMEOUT}" == "YOUR_NODEPOOL_TIMEOUT" ]]; then
    NODEPOOL_TIMEOUT="3600"
  fi

  set +e
  # [START hypercomputer_gpu_train_ray_verl_std_create_nodepool]
  RESERVATION_ARGS=("--reservation-affinity=none")
  if [ -n "${RESERVATION:-}" ]; then
    RESERVATION_ARGS=("--reservation-affinity=specific" "--reservation=${RESERVATION}")
  fi
  gcloud container node-pools create gpu-pool \
      --cluster="${CLUSTER_NAME}" \
      --location="${CONTROL_PLANE_REGION}" \
      --node-locations="${NODE_ZONE}" \
      --machine-type="${MACHINE_TYPE}" \
      --accelerator="type=${GPU_TYPE},count=8,gpu-driver-version=DEFAULT" \
      --num-nodes=2 \
      "${RESERVATION_ARGS[@]}" \
      --additional-node-network="network=${GVNIC_NETWORK_PREFIX}-net,subnetwork=${GVNIC_NETWORK_PREFIX}-sub" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-0" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-1" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-2" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-3" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-4" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-5" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-6" \
      --additional-node-network="network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-7" \
      --project="${PROJECT_ID}"
  # [END hypercomputer_gpu_train_ray_verl_std_create_nodepool]
  NODEPOOL_CREATE_RC=$?
  set -e

  if [ "${NODEPOOL_CREATE_RC}" -ne 0 ]; then
    OPERATION_ID=$(gcloud container operations list \
        --location="${CONTROL_PLANE_REGION}" \
        --project="${PROJECT_ID}" \
        --filter="operationType=CREATE_NODE_POOL AND status=RUNNING AND targetLink~${CLUSTER_NAME}/nodePools/gpu-pool" \
        --format="value(name)" | head -n 1)
    if [ -n "${OPERATION_ID}" ]; then
      echo "Node pool creation operation ${OPERATION_ID} is still running; waiting up to ${NODEPOOL_TIMEOUT}s..."
      if ! timeout "${NODEPOOL_TIMEOUT}" bash -c '
        while [[ "$(gcloud container operations describe "'"${OPERATION_ID}"'" --location="'"${CONTROL_PLANE_REGION}"'" --project="'"${PROJECT_ID}"'" --format="value(status)")" == "RUNNING" ]]; do
          sleep 15
        done
      '; then
        echo "Error: Nodepool creation timed out after ${NODEPOOL_TIMEOUT} seconds."
        gcloud container operations describe "${OPERATION_ID}" \
            --location="${CONTROL_PLANE_REGION}" \
            --project="${PROJECT_ID}" || true
        exit 1
      fi
    fi
  fi

  if [[ "$(gcloud container node-pools describe gpu-pool --cluster="${CLUSTER_NAME}" --location="${CONTROL_PLANE_REGION}" --project="${PROJECT_ID}" --format="value(status)" 2>/dev/null)" != "RUNNING" ]]; then
    echo "Error: gpu-pool failed to reach RUNNING state."
    exit 1
  fi
else
  echo "Node pool gpu-pool already exists."
fi

# Install NCCL RDMA installer
echo "Installing NCCL RDMA installer..."
# [START hypercomputer_gpu_train_ray_verl_std_install_nccl]
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/refs/heads/master/gpudirect-rdma/nccl-rdma-installer.yaml
# [END hypercomputer_gpu_train_ray_verl_std_install_nccl]

echo "Cluster setup complete."
