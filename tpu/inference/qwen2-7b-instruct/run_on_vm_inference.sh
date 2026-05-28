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

export MODEL_NAME="Qwen/Qwen2-7B-Instruct"
# [START hypercomputer_tpu_infer_qwen2_7b_start_container]
export DOCKER_URI="vllm/vllm-tpu:v0.18.0"
export CONTAINER_NAME="${USER}-vllm"
export MAX_MODEL_LEN=4096
export TP=1 # number of chips

sudo docker run -d --name "${CONTAINER_NAME}" \
    --privileged --net=host \
    -v /dev/shm:/dev/shm \
    --shm-size 10gb \
    -e "HF_HOME=/dev/shm" \
    -e "HF_TOKEN=${HF_TOKEN}" \
    -p 8000:8000 "${DOCKER_URI}" \
        vllm serve ${MODEL_NAME} \
            --seed 42 \
            --gpu-memory-utilization 0.98 \
            --max-num-batched-tokens 1024 \
            --max-num-seqs 128 \
            --tensor-parallel-size $TP \
            --max-model-len $MAX_MODEL_LEN
# [END hypercomputer_tpu_infer_qwen2_7b_start_container]

while ! sudo docker logs "${CONTAINER_NAME}" 2>&1 | grep -q 'Application startup complete.'; do
  if ! sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container ${CONTAINER_NAME} has stopped or failed to start." >&2
    exit 1
  fi
  sleep 10
done

# [START hypercomputer_tpu_infer_qwen2_7b_test_inference]
sudo docker exec "${CONTAINER_NAME}" \
  curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "The future of AI is",
        "max_tokens": 200,
        "temperature": 0
      }'
# [END hypercomputer_tpu_infer_qwen2_7b_test_inference]
