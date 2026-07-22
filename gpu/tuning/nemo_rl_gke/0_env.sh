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

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_env]
export CONTROL_PLANE_REGION="YOUR_REGION"
export NODE_ZONE="YOUR_NODE_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export GPU_TYPE="YOUR_GPU_TYPE"
export MACHINE_TYPE="YOUR_MACHINE_TYPE"
export KSA_NAME="generic-ksa"
export NAMESPACE="default"
export RESERVATION="RESERVATION_NAME"
export LUSTRE_NAME="CHOSEN_LUSTRE_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export WANDB_API_KEY="YOUR_WANDB_API_KEY"

export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_env]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_network_env]
export NETWORK="NETWORK_NAME"
export GVNIC_NETWORK_PREFIX="GVNIC_NAME"
export RDMA_NETWORK_PREFIX="RDMA_NAME"
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_network_env]
