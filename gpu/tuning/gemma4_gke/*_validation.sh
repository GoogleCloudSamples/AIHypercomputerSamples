#!/bin/bash
#
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

declare -r JOB_NAME="finetune-job"
declare -r LOG_FILE="$(mktemp)"

echo "[$(date)] ==================== Starting Validation... ===================="

echo "Fetching full logs for verification..."
kubectl logs "jobs/${JOB_NAME}" > "${LOG_FILE}"

# Count how many times "Training finished." appears
declare -r TRAINING_COUNT="$(grep -o "Training finished." "${LOG_FILE}" | wc -l)"
if [[ "${TRAINING_COUNT}" -ne 8 ]]; then
    echo "Validation Failed! Count = ${TRAINING_COUNT}"
    exit 1
fi

# Verify that the fine-tuned adapter was pushed to the Hugging Face Hub
HF_USERNAME="$(curl -sSf -H "Authorization: Bearer ${HF_TOKEN}" \
    https://huggingface.co/api/whoami-v2 \
    | python3 -c "import json, sys; print(json.load(sys.stdin)['name'])")"
declare -r HF_REPO="${HF_USERNAME}/gemma-31b-text-to-sql"
if ! curl -sSf -H "Authorization: Bearer ${HF_TOKEN}" \
    "https://huggingface.co/api/models/${HF_REPO}" \
    | grep -q "adapter_model.safetensors"; then
    echo "Validation Failed! adapter_model.safetensors not found in ${HF_REPO}"
    exit 1
fi
echo "Fine-tuned adapter found at https://huggingface.co/${HF_REPO}"

# Verify that the pushed adapter contains text decoder LoRA weights by reading
# only the safetensors header (8-byte length prefix followed by JSON).
declare -r ADAPTER_URL="https://huggingface.co/${HF_REPO}/resolve/main/\
adapter_model.safetensors"
HEADER_LEN="$(curl -sSfL -r 0-7 -H "Authorization: Bearer ${HF_TOKEN}" \
    "${ADAPTER_URL}" \
    | python3 -c "import struct, sys
print(struct.unpack('<Q', sys.stdin.buffer.read(8))[0])")"
TENSOR_COUNTS="$(curl -sSfL -r "8-$((HEADER_LEN + 7))" \
        -H "Authorization: Bearer ${HF_TOKEN}" "${ADAPTER_URL}" \
    | python3 -c "
import json, sys
keys = [k for k in json.load(sys.stdin) if k != '__metadata__']
print(sum('language_model' in k for k in keys),
      sum('vision_tower' in k for k in keys))")"
read -r TEXT_DECODER_TENSORS VISION_TENSORS <<< "${TENSOR_COUNTS}"
echo "Adapter tensors: text_decoder=${TEXT_DECODER_TENSORS}" \
    "vision_tower=${VISION_TENSORS}"
if [[ "${TEXT_DECODER_TENSORS}" -eq 0 ]]; then
    echo "Validation Failed! No text decoder LoRA weights in ${HF_REPO}"
    exit 1
fi

echo "Validation Succeeded!"
