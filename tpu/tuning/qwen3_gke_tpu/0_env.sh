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

# [START hypercomputer_tpu_tune_qwen3_sft_env]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export GCS_BUCKET="YOUR_GCS_BUCKET"
export CLOUD_IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT/maxtext-images/maxtext_base:latest"
export TPU_TYPE="v6e-32"
export CLUSTER_NODEPOOL_COUNT=1
export PW_CPU_MACHINE_TYPE="c4d-standard-96"
export RESERVATION="YOUR_RESERVATION_NAME"
export MODEL_NAME="qwen3-14b"
export HF_TOKEN="YOUR_HF_TOKEN"
# [END hypercomputer_tpu_tune_qwen3_sft_env]
