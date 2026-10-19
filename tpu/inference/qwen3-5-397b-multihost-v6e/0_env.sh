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

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export MACHINE_TYPE="ct6e-standard-4t"
export NODE_POOL_NAME_0="tpuv6e-pool-0"
export NODE_POOL_NAME_1="tpuv6e-pool-1"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export GCS_BUCKET="YOUR_GCS_BUCKET"
export HF_TOKEN="YOUR_HF_TOKEN"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_env]

# Set USE_FLEX_START="true" (or leave RESERVATION_NAME empty / "YOUR_RESERVATION_NAME")
# to provision the TPU v6e node pools using DWS Flex-Start with autoscaling instead of a reservation.
export USE_FLEX_START="${USE_FLEX_START:-YOUR_USE_FLEX_START}"

# Set USE_SPOT="true" to provision the TPU v6e node pools using Spot VMs.
export USE_SPOT="${USE_SPOT:-YOUR_USE_SPOT}"

# Timeout for waiting for the model download job to complete in 2_download_model.sh.
# Default value is 3600s (1 hour) to account for downloading and uploading the model weights.
export DOWNLOAD_TIMEOUT="YOUR_DOWNLOAD_TIMEOUT"

# Set SKIP_BENCHMARK="true" to skip the 8k/1k benchmark step in 4_run_benchmark.sh.
export SKIP_BENCHMARK="${SKIP_BENCHMARK:-YOUR_SKIP_BENCHMARK}"
