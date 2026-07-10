#!/bin/bash
#
#  Copyright 2026 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -euo pipefail

echo "[$(date)] ========== Creating GKE Cluster... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_cluster_create_standard]
gcloud container clusters create ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --workload-pool=${PROJECT_ID}.svc.id.goog \
    --enable-dataplane-v2 \
    --enable-ip-alias \
    --enable-multi-networking \
    --addons=RayOperator,LustreCsiDriver \
    --enable-legacy-lustre-port \
    --machine-type=n2-highmem-80 \
    --num-nodes=1 \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-autoscaling \
    --network=${NETWORK}
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_cluster_create_standard]

echo "Verifying cluster status..."
STATUS=$(gcloud container clusters describe "$CLUSTER_NAME" --region "$CONTROL_PLANE_REGION" --format="value(status)")

if [ "$STATUS" = "RUNNING" ]; then
    echo "Success! Cluster $CLUSTER_NAME is RUNNING and ready for deployment."
else
    echo "Warning: Cluster is in '$STATUS' state."
    exit 1
fi

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_cluster_get_creds]
gcloud container clusters get-credentials $CLUSTER_NAME \
    --location=$CONTROL_PLANE_REGION
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_cluster_get_creds]

echo "[$(date)] ========== Creating Node Pools... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_node_pool_create]
gcloud container node-pools create gpu-pool \
    --cluster=${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --node-locations=${NODE_ZONE} \
    --machine-type=${MACHINE_TYPE} \
    --accelerator=type=${GPU_TYPE},count=8,gpu-driver-version=DEFAULT \
    --reservation-affinity=specific \
    --reservation=${RESERVATION} \
    --enable-autoscaling \
    --num-nodes=0 \
    --total-max-nodes=2 \
    --additional-node-network=network=${GVNIC_NETWORK_PREFIX}-net,subnetwork=${GVNIC_NETWORK_PREFIX}-sub \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-0 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-1 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-2 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-3 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-4 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-5 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-6 \
    --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-7
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_node_pool_create]

echo "[$(date)] ========== Installing NCCL RDMA... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_nccl_rdma_installer]
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/refs/heads/master/gpudirect-rdma/nccl-rdma-installer.yaml
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_nccl_rdma_installer]

echo "[$(date)] ========== Setting up network mapping... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_network_mapping]
envsubst < network-mapping.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_network_mapping]
