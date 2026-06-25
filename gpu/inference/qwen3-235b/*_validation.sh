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

echo "Waiting for GKE deployment/vllm-qwen3-deployment to be ready..."
kubectl wait \
    --for=condition=Available \
    --timeout=1800s deployment/vllm-qwen3-deployment

echo "Setting up port-forwarding to qwen3-service on port 8000..."
kubectl port-forward service/qwen3-service 8000:8000 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Polling /health endpoint..."
LIMIT=300
count=0
until curl -s http://localhost:8000/health >/dev/null; do
  if [ "$count" -ge "$LIMIT" ]; then
    echo "Timeout waiting for model endpoint to become healthy." >&2
    exit 1
  fi
  if ! kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  sleep 2
  count=$((count+1))
done

echo "Executing test query to Qwen3 model..."
RESPONSE=$(curl -s http://127.0.0.1:8000/v1/chat/completions \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-235B-A22B-Instruct-2507",
    "messages": [
      {
        "role": "user",
        "content": "Describe a GPU in one short sentence?"
      }
    ]
  }')

echo "Verifying JSON completion structure..."
if echo "$RESPONSE" | grep -q '"object": *"chat.completion"'; then
  echo "Validation Succeeded! Model responded with a valid chat completion."
else
  echo "Validation Failed! Expected chat.completion JSON structure. Response was:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
