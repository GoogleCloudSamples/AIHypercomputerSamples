#!/bin/bash

set -euo pipefail

source 0_env.sh

# Create GKE Standard Cluster
if ! gcloud container clusters describe ${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating GKE Standard cluster ${CLUSTER_NAME}..."
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
else
  echo "Cluster ${CLUSTER_NAME} already exists."
fi

# Get credentials
echo "Getting credentials for cluster ${CLUSTER_NAME}..."
gcloud container clusters get-credentials ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --project=${PROJECT_ID}

# Create GPU Node Pool
if ! gcloud container node-pools describe gpu-pool --cluster=${CLUSTER_NAME} --location=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating GPU node pool gpu-pool..."
  
  # Build the gcloud command. We need to handle reservation if it is set.
  CMD="gcloud container node-pools create gpu-pool \
      --cluster=${CLUSTER_NAME} \
      --location=${CONTROL_PLANE_REGION} \
      --node-locations=${NODE_ZONE} \
      --machine-type=${MACHINE_TYPE} \
      --accelerator=type=${GPU_TYPE},count=8,gpu-driver-version=DEFAULT \
      --enable-autoscaling \
      --num-nodes=2 \
      --total-max-nodes=10 \
      --additional-node-network=network=${GVNIC_NETWORK_PREFIX}-net,subnetwork=${GVNIC_NETWORK_PREFIX}-sub \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-0 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-1 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-2 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-3 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-4 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-5 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-6 \
      --additional-node-network=network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-7 \
      --project=${PROJECT_ID}"

  if [ -n "${RESERVATION:-}" ]; then
    CMD="${CMD} --reservation-affinity=specific --reservation=${RESERVATION}"
  else
    CMD="${CMD} --reservation-affinity=none"
  fi

  eval $CMD
else
  echo "Node pool gpu-pool already exists."
fi

# Install NCCL RDMA installer
echo "Installing NCCL RDMA installer..."
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/refs/heads/master/gpudirect-rdma/nccl-rdma-installer.yaml

echo "Cluster setup complete."
