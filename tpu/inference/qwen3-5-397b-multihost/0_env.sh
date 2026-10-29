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

export TPU_TYPE="${TPU_TYPE:-v7x}"

if [[ "${TPU_TYPE}" == "v6e" ]]; then
export TPU_TYPE="v6e"
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_env_v6e]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export MACHINE_TYPE="ct6e-standard-4t"
export NODE_POOL_NAME_0="np-0"
export NODE_POOL_NAME_1="np-1"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export GCS_BUCKET="YOUR_GCS_BUCKET"
export HF_TOKEN="YOUR_HF_TOKEN"
export VLLM_IMAGE="vllm/vllm-torchtpu:v0.29.0@sha256:3976ccc1a69ffd361e0a7d2831fe317f6b685636014f426321a39ae02f8da0dc"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_env_v6e]

else
export TPU_TYPE="v7x"
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export MACHINE_TYPE="tpu7x-standard-4t"
export WORKLOAD_POLICY_NAME="${CLUSTER_NAME}-policy"
export NODE_POOL_NAME_0="np-0"
export NODE_POOL_NAME_1="np-1"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export GCS_BUCKET="YOUR_GCS_BUCKET"
export HF_TOKEN="YOUR_HF_TOKEN"
export VLLM_IMAGE="vllm/vllm-torchtpu:v0.29.0@sha256:3976ccc1a69ffd361e0a7d2831fe317f6b685636014f426321a39ae02f8da0dc"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_env]
fi

if [[ "${TPU_TYPE}" == "v6e" ]]; then
  export MODEL_NAME="Qwen/Qwen3.5-397B-A17B-FP8"
  export SERVER_MANIFEST="v6e_qwen3_server_multihost_slice.yaml"
  export BENCHMARK_MANIFEST="v6e_qwen3_benchmark_multihost_slice.yaml"
  export DEPLOYMENT_NAME="vllm-qwen3"
  export SERVICE_NAME="vllm-qwen3-service"
  export BENCHMARK_POD="qwen3-bench-8k1k"
else
  export MODEL_NAME="Qwen/Qwen3.5-397B-A17B-FP8"
  export SERVER_MANIFEST="v7x_qwen3_5_server_multihost_slice.yaml"
  export BENCHMARK_MANIFEST="v7x_qwen3_5_benchmark_multihost_slice.yaml"
  export DEPLOYMENT_NAME="vllm-qwen3-5"
  export SERVICE_NAME="vllm-qwen3-5-service"
  export BENCHMARK_POD="qwen3-5-bench-8k1k"
fi

# Timeout for waiting for the model download job to complete in 2_download_model.sh.
# Default value is 7200s (2 hours) to account for downloading and uploading ~400GB of weights.
export DOWNLOAD_TIMEOUT="YOUR_DOWNLOAD_TIMEOUT"

# Set SKIP_BENCHMARK="true" to skip the 8k/1k benchmark step in 4_run_benchmark.sh.
export SKIP_BENCHMARK="${SKIP_BENCHMARK:-YOUR_SKIP_BENCHMARK}"
