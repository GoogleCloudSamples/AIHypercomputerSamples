#!/bin/bash

set -euo pipefail

source 0_env.sh

# Create a VPC network for the gVNIC interface:
if ! gcloud compute networks describe ${GVNIC_NETWORK_PREFIX}-net --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating VPC network ${GVNIC_NETWORK_PREFIX}-net..."
  gcloud compute networks create ${GVNIC_NETWORK_PREFIX}-net \
      --subnet-mode=custom \
      --project=${PROJECT_ID}
else
  echo "VPC network ${GVNIC_NETWORK_PREFIX}-net already exists."
fi

if ! gcloud compute networks subnets describe ${GVNIC_NETWORK_PREFIX}-sub --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating subnet ${GVNIC_NETWORK_PREFIX}-sub..."
  gcloud compute networks subnets create ${GVNIC_NETWORK_PREFIX}-sub \
      --network=${GVNIC_NETWORK_PREFIX}-net \
      --region=${CONTROL_PLANE_REGION} \
      --range=192.168.0.0/24 \
      --project=${PROJECT_ID}
else
  echo "Subnet ${GVNIC_NETWORK_PREFIX}-sub already exists."
fi

if ! gcloud compute firewall-rules describe ${GVNIC_NETWORK_PREFIX}-internal --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating firewall rule ${GVNIC_NETWORK_PREFIX}-internal..."
  gcloud compute firewall-rules create ${GVNIC_NETWORK_PREFIX}-internal \
      --network=${GVNIC_NETWORK_PREFIX}-net \
      --action=ALLOW \
      --rules=tcp:0-65535,udp:0-65535,icmp \
      --source-ranges=192.168.0.0/16 \
      --project=${PROJECT_ID}
else
  echo "Firewall rule ${GVNIC_NETWORK_PREFIX}-internal already exists."
fi

# Create a VPC network and subnets for RDMA with 8 subnets for 8 GPUs:
if ! gcloud compute networks describe ${RDMA_NETWORK_PREFIX}-net --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Creating VPC network ${RDMA_NETWORK_PREFIX}-net..."
  gcloud beta compute networks create ${RDMA_NETWORK_PREFIX}-net \
      --network-profile=${NODE_ZONE}-vpc-roce \
      --subnet-mode=custom \
      --project=${PROJECT_ID}
else
  echo "VPC network ${RDMA_NETWORK_PREFIX}-net already exists."
fi

echo "Creating RDMA subnets..."
for N in $(seq 0 7); do
  if ! gcloud compute networks subnets describe ${RDMA_NETWORK_PREFIX}-sub-$N --region=${CONTROL_PLANE_REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
    gcloud compute networks subnets create ${RDMA_NETWORK_PREFIX}-sub-$N \
      --network=${RDMA_NETWORK_PREFIX}-net \
      --region=${CONTROL_PLANE_REGION} \
      --range=192.168.$((N+1)).0/24 \
      --project=${PROJECT_ID} &
  else
    echo "Subnet ${RDMA_NETWORK_PREFIX}-sub-$N already exists."
  fi
done
wait

echo "GVNIC Network setup complete: ${GVNIC_NETWORK_PREFIX}-net"
echo "RDMA Network setup complete: ${RDMA_NETWORK_PREFIX}-net"
