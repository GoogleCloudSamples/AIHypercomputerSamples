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

# [START hypercomputer_tpu_tune_gemma4_26b_rl_env_v2]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION" # for example, us-central1
export ZONE="YOUR_ZONE" # for example, us-central1-b
export CLUSTER_NAME="YOUR_CLUSTER_NAME" # maximum 20 chars; start with a-z; only a-z, 0-9, -
export GCS_BUCKET="YOUR_BUCKET_NAME" # Globally unique Cloud Storage bucket name
export CLOUD_IMAGE_NAME="us-docker.pkg.dev/cloud-tpu-images/maxtext-images/tpu_post_training:0.2.4" # Prebuilt MaxText post-training container image
export COMPUTE_TYPE="ct6e-standard-4t" # GCE machine type for TPU v6e hosts
export TOPOLOGY="4x8" # TPU slice topology (32 chips on v6e)
export CLUSTER_NODEPOOL_COUNT=1 # Number of TPU node pools (slices) to provision
export RESERVATION="YOUR_RESERVATION_NAME" # TPU v6e reservation name
export MODEL_NAME="gemma4-26b" # MaxText model name for google/gemma-4-26b-a4b-it
export CLUSTER_TOOLKIT_VERSION="v1.103.0" # Cluster Toolkit release version
export HF_TOKEN="YOUR_HF_TOKEN"
# [END hypercomputer_tpu_tune_gemma4_26b_rl_env_v2]

# Ensure CLUSTER_NAME is <= 20 chars so service account IDs (${CLUSTER_NAME}-gke-np-sa) stay <= 30 chars
if [[ "$CLUSTER_NAME" == pkb-*-cluster ]]; then
  export CLUSTER_NAME="${CLUSTER_NAME%-cluster}"
elif [ ${#CLUSTER_NAME} -gt 20 ]; then
  export CLUSTER_NAME="${CLUSTER_NAME:0:20}"
fi
