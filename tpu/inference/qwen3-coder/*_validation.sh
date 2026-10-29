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

kubectl port-forward service/sglang-service 8000:8000 &
PORT_FORWARD_PID=$!
trap 'kill $PORT_FORWARD_PID 2>/dev/null || true' EXIT
sleep 5

if [[ "${ACCELERATOR_TYPE:-v7x}" == "v6e" ]]; then
  MODEL_ID="Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8"
elif [[ "${ACCELERATOR_TYPE:-v7x}" == "v7x" ]]; then
  MODEL_ID="Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8"
else
  echo "Unsupported ACCELERATOR_TYPE: ${ACCELERATOR_TYPE}"
  exit 1
fi

RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL_ID}\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"Explain quicksort in two sentences.\"}
    ],
    \"max_tokens\": 60,
    \"temperature\": 0.0
  }")

echo "${RESPONSE}"

if ! echo "${RESPONSE}" | grep -q '"choices"'; then
  echo "ERROR: Inference request did not return a valid completion response."
  exit 1
fi

echo "Validation succeeded."
