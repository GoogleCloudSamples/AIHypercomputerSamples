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

echo "[$(date)] ========== Creating VPC network for the gVNIC interface... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_gvnic_vpc]
gcloud compute networks create ${NETWORK} --subnet-mode=auto

gcloud compute networks create ${GVNIC_NETWORK_PREFIX}-net \
    --subnet-mode=custom

gcloud compute networks subnets create ${GVNIC_NETWORK_PREFIX}-sub \
    --network=${GVNIC_NETWORK_PREFIX}-net \
    --region=${CONTROL_PLANE_REGION} \
    --range=192.168.0.0/24

gcloud compute firewall-rules create ${GVNIC_NETWORK_PREFIX}-internal \
    --network=${GVNIC_NETWORK_PREFIX}-net \
    --action=ALLOW \
    --rules=tcp:0-65535,udp:0-65535,icmp \
    --source-ranges=192.168.0.0/16
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_gvnic_vpc]

echo "[$(date)] ========== Creating VPC network and subnets for RDMA... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_rdma_vpc]
gcloud compute networks create ${RDMA_NETWORK_PREFIX}-net \
    --network-profile=${NODE_ZONE}-vpc-roce \
    --subnet-mode=custom

for N in $(seq 0 7); do
  gcloud compute networks subnets create ${RDMA_NETWORK_PREFIX}-sub-$N \
    --network=${RDMA_NETWORK_PREFIX}-net \
    --region=${CONTROL_PLANE_REGION} \
    --range=192.168.$((N+1)).0/24 &
done
wait
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_rdma_vpc]