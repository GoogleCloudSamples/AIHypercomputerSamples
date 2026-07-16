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

echo "[$(date)] ==================== The model is deployed. Setting up port forwarding... ===================="
# Set up port forwarding to the deepseek-v3-2 model
kubectl port-forward service/deepseek-service 8000:8000 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for port forwarding to be ready
echo "Waiting for port forwarding to be ready..."
TIMEOUT=60
INTERVAL=1
ELAPSED=0
until curl -s http://localhost:8000/health >/dev/null; do
  if ! kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Error: Timeout waiting for port forwarding to be ready." >&2
    exit 1
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "[$(date)] ==================== Checking model availability endpoint... ===================="
DEPLOYED_MODEL=$(curl -s http://localhost:8000/v1/models | jq -r '.data[0].id // empty')

if [ ! -z "$DEPLOYED_MODEL" ]; then
  echo "Validation Succeeded! Model $DEPLOYED_MODEL is available"
else
  echo "Validation Failed! Model is not available"
  exit 1
fi

# Send request to the model
echo "Sending request to the model..."
# [START hypercomputer_gpu_infer_deepseek32_interact]
time curl http://127.0.0.1:8000/v1/completions \
   -X POST \
   -H "Content-Type: application/json" \
   -d '{
     "model": "deepseek-ai/DeepSeek-V3.2-Speciale",
     "prompt": "<|im_start|>user\nExplain the ReAct (Reasoning + Acting) pattern in Agentic AI. Provide a concise Python pseudocode example showing the loop. Keep the explanation under 300 words.<|im_end|>\n<|im_start|>assistant\n",
     "max_tokens": 1024,
     "temperature": 0.7,
     "stream": false,
     "stop": ["<|im_end|>"]
   }' | jq .
# [END hypercomputer_gpu_infer_deepseek32_interact]
echo "[$(date)] ==================== Interaction with the model is finished ===================="
