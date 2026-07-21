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

# Create a VPC network for the gVNIC interface:
echo "Creating VPC network ${GVNIC_NETWORK_PREFIX}-net..."
  
# [START hypercomputer_gpu_train_ray_verl_std_create_gvnic_net]
gcloud compute networks create ${GVNIC_NETWORK_PREFIX}-net \
  --subnet-mode=custom \
  --project=${PROJECT_ID}

gcloud compute networks subnets create ${GVNIC_NETWORK_PREFIX}-sub \
  --network=${GVNIC_NETWORK_PREFIX}-net \
  --region=${CONTROL_PLANE_REGION} \
  --range=192.168.0.0/24 \
  --project=${PROJECT_ID}

gcloud compute firewall-rules create ${GVNIC_NETWORK_PREFIX}-internal \
  --network=${GVNIC_NETWORK_PREFIX}-net \
  --action=ALLOW \
  --rules=tcp:0-65535,udp:0-65535,icmp \
  --source-ranges=192.168.0.0/16 \
  --project=${PROJECT_ID}
# [END hypercomputer_gpu_train_ray_verl_std_create_gvnic_net]


# Create a VPC network and subnets for RDMA with 8 subnets for 8 GPUs:
# [START hypercomputer_gpu_train_ray_verl_std_create_rdma_net]
gcloud beta compute networks create ${RDMA_NETWORK_PREFIX}-net \
  --network-profile=${NODE_ZONE}-vpc-roce \
  --subnet-mode=custom \
  --project=${PROJECT_ID}
# [END hypercomputer_gpu_train_ray_verl_std_create_rdma_net]

echo "Creating RDMA subnets..."
# [START hypercomputer_gpu_train_ray_verl_std_create_rdma_subs]
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
# [END hypercomputer_gpu_train_ray_verl_std_create_rdma_subs]

echo "GVNIC Network setup complete: ${GVNIC_NETWORK_PREFIX}-net"
echo "RDMA Network setup complete: ${RDMA_NETWORK_PREFIX}-net"

