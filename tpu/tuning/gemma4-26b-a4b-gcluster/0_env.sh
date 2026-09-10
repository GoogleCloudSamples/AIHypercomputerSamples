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

# [START hypercomputer_tpu_tune_gemma4_26b_rl_env]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export REPOSITORY_NAME="YOUR_REPOSITORY_NAME"
export GCS_BUCKET="YOUR_BUCKET_NAME"
export CLOUD_IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT}/${REPOSITORY_NAME}/maxtext_base:latest"
export COMPUTE_TYPE="ct6e-standard-4t"
export TPU_TYPE="v6e-64"
export TOPOLOGY="8x8"
export CLUSTER_NODEPOOL_COUNT=1
export PW_CPU_MACHINE_TYPE="c4d-standard-96"
export RESERVATION="YOUR_RESERVATION_NAME"
export MODEL_NAME="gemma4-26b"
export HF_TOKEN="YOUR_HF_TOKEN"
# [END hypercomputer_tpu_tune_gemma4_26b_rl_env]

# Override for sample automation using prebuilt image
export CLOUD_IMAGE_NAME="us-docker.pkg.dev/cloud-tpu-images/maxtext-images/tpu_post_training:0.2.4"

# [START hypercomputer_tpu_tune_gemma4_26b_rl_env_v2]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export GCS_BUCKET="YOUR_BUCKET_NAME"
export CLOUD_IMAGE_NAME="us-docker.pkg.dev/cloud-tpu-images/maxtext-images/tpu_post_training:0.2.4"
export COMPUTE_TYPE="ct6e-standard-4t"
export TPU_TYPE="v6e-64"
export TOPOLOGY="8x8"
export CLUSTER_NODEPOOL_COUNT=1
export PW_CPU_MACHINE_TYPE="c4d-standard-96"
export RESERVATION="YOUR_RESERVATION_NAME"
export MODEL_NAME="gemma4-26b"
export HF_TOKEN="YOUR_HF_TOKEN"
# [END hypercomputer_tpu_tune_gemma4_26b_rl_env_v2]

# Ensure CLUSTER_NAME is <= 20 chars so service account IDs (${CLUSTER_NAME}-gke-np-sa) stay <= 30 chars
if [[ "$CLUSTER_NAME" == pkb-*-cluster ]]; then
  export CLUSTER_NAME="${CLUSTER_NAME%-cluster}"
elif [ ${#CLUSTER_NAME} -gt 20 ]; then
  export CLUSTER_NAME="${CLUSTER_NAME:0:20}"
fi
