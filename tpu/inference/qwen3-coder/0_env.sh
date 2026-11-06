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

export ACCELERATOR_TYPE="${ACCELERATOR_TYPE:-v7x}"

if [[ "${ACCELERATOR_TYPE}" == "v6e" ]]; then
export ACCELERATOR_TYPE="v6e"
# [START hypercomputer_tpu_infer_qwen3_coder_env_v6e]
export CLUSTER_NAME="YOUR_CLUSTER_NAME" # <= 40 chars; start with a-z; only a-z, 0-9, -
export PROJECT_ID="YOUR_PROJECT_ID" # Your Google Cloud project ID
export REGION="YOUR_REGION" # for example, us-central1
export ZONE="YOUR_ZONE" # for example, us-central1-b
export RESERVATION="YOUR_RESERVATION_NAME" # TPU v6e reservation name (if using a reservation)
export HF_TOKEN="YOUR_HF_TOKEN" # Hugging Face access token
export SGLANG_IMAGE="lmsysorg/sglang:v0.1.0-tpu"
# [END hypercomputer_tpu_infer_qwen3_coder_env_v6e]

else
export ACCELERATOR_TYPE="v7x"
# [START hypercomputer_tpu_infer_qwen3_coder_env]
export CLUSTER_NAME="YOUR_CLUSTER_NAME" # <= 20 chars; start with a-z; only a-z, 0-9, -
export PROJECT_ID="YOUR_PROJECT_ID" # Your Google Cloud project ID
export REGION="YOUR_REGION" # for example, us-central1
export ZONE="YOUR_ZONE" # for example, us-central1-c
export RESERVATION="YOUR_RESERVATION_NAME" # TPU7x reservation name (if using a reservation)
export HF_TOKEN="YOUR_HF_TOKEN" # Hugging Face access token
export SGLANG_IMAGE="lmsysorg/sglang:v0.1.0-tpu"
# [END hypercomputer_tpu_infer_qwen3_coder_env]
fi
