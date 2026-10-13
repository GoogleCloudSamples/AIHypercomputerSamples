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

# [START hypercomputer_tpu_infer_qwen3_5_397b_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export MACHINE_TYPE="tpu7x-standard-4t"
export NODE_POOL_NAME="np-0"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export NETWORK="YOUR_NETWORK_NAME"
export SUBNETWORK="YOUR_SUBNETWORK_NAME"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_env]

# Set USE_SPOT="true" (or leave RESERVATION_NAME empty / "spot" / "none") to
# provision the TPU v7x node pool using Spot VMs instead of a reservation.
export USE_SPOT="${USE_SPOT:-false}"

# Set SKIP_BENCHMARK="true" to skip the 8k/1k benchmark step in 4_run_benchmark.sh.
export SKIP_BENCHMARK="${SKIP_BENCHMARK:-false}"
