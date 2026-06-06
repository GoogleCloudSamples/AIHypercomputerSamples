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

set -euo pipefail

export DOCKER_URI="vllm/vllm-tpu:v0.18.0"
export CONTAINER_NAME="${USER}-vllm"
export MAX_MODEL_LEN=4096
export TP=1 # number of chips

# [START hypercomputer_tpu_infer_qwen2_7b_run_benchmark_pip]
sudo docker exec "${CONTAINER_NAME}" pip install datasets
# [END hypercomputer_tpu_infer_qwen2_7b_run_benchmark_pip]

# [START hypercomputer_tpu_infer_qwen2_7b_run_benchmark]
sudo docker exec "${CONTAINER_NAME}" \
    vllm bench serve \
        --backend vllm \
        --dataset-name random \
        --num-prompts 1000 \
        --seed 100
# [END hypercomputer_tpu_infer_qwen2_7b_run_benchmark]
