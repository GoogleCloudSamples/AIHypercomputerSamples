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

# Set TPU_TYPE="v7x" (default) or TPU_TYPE="v6e" to select the target TPU generation.
export TPU_TYPE="${TPU_TYPE:-v7x}"

if [[ "${TPU_TYPE}" == "v6e" ]]; then
export TPU_TYPE="v6e"
# [START hypercomputer_tpu_infer_qwen3_5_397b_env_v6]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export MACHINE_TYPE="ct6e-standard-4t"
export NODE_POOL_NAME="np-0"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export NETWORK="YOUR_NETWORK_NAME"
export SUBNETWORK="YOUR_SUBNETWORK_NAME"
export VLLM_IMAGE="YOUR_VLLM_TPU_IMAGE"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_env_v6]
else
export TPU_TYPE="v7x"
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
export VLLM_IMAGE="YOUR_VLLM_TPU_IMAGE"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_env]
fi

if [[ "${TPU_TYPE}" == "v6e" ]]; then
  export MODEL_NAME="Qwen/Qwen3-30B-A3B-FP8"
  export SERVER_MANIFEST="qwen3_server.yaml"
  export DEPLOYMENT_NAME="vllm-qwen3"
  export SERVICE_NAME="vllm-qwen3-service"
  export BENCHMARK_MANIFEST="qwen3-benchmark-8k1k.yaml"
  export BENCHMARK_POD="qwen3-bench-8k1k"
else
  export MODEL_NAME="Qwen/Qwen3.5-397B-A17B-FP8"
  export SERVER_MANIFEST="qwen3_5_server.yaml"
  export DEPLOYMENT_NAME="vllm-qwen3-5"
  export SERVICE_NAME="vllm-qwen3-5-service"
  export BENCHMARK_MANIFEST="qwen3_5-benchmark-8k1k.yaml"
  export BENCHMARK_POD="qwen3-5-bench-8k1k"
fi

# Set USE_SPOT="true" (or leave RESERVATION_NAME empty / "spot" / "none") to
# provision the TPU node pool using Spot VMs instead of a reservation.
export USE_SPOT="${USE_SPOT:-false}"

# Set SKIP_BENCHMARK="true" to skip the 8k/1k benchmark step in 4_run_benchmark.sh.
export SKIP_BENCHMARK="${SKIP_BENCHMARK:-false}"
