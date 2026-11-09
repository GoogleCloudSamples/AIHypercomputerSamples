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

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export CONTROL_PLANE_REGION="YOUR_REGION"
export NODE_ZONE="YOUR_ZONE"
export LUSTRE_ZONE="YOUR_LUSTRE_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export GKE_VERSION="1.35"
export GPU_TYPE="YOUR_GPU_TYPE"
export MACHINE_TYPE="YOUR_MACHINE_TYPE"
export GPU_DRIVER_VERSION="latest"
export NUM_GPU_NODES="2"
export CPU_MACHINE_TYPE="n2-highmem-16"
export NODE_DISK_SIZE_GB="500"
export RESERVATION="YOUR_RESERVATION_NAME"
export LUSTRE_NAME="YOUR_LUSTRE_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export WANDB_API_KEY="YOUR_WANDB_API_KEY"

export NEMO_RL_VERSION="v0.8.0"
export MODEL_ID="google/gemma-4-12B-it"
export NEMO_RL_RECIPE="examples/configs/recipes/llm/dapo-gemma4-12b-it-2n8g-automodel.yaml"
export GRPO_MAX_STEPS="10"
export RUN_NAME="nemo-rl-gemma4-12b"
export NEMO_RL_CHART_COMMIT="87fa0575c977b96f6d3af2cab58c9128f3cf0dc3"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_env]

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_network_env]
export NETWORK_PREFIX="YOUR_NETWORK_NAME"
export NETWORK="${NETWORK_PREFIX}-nemo-rl"
export GVNIC_NETWORK_PREFIX="YOUR_GVNIC_NETWORK_PREFIX"
export RDMA_NETWORK_PREFIX="YOUR_RDMA_NETWORK_PREFIX"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_network_env]
