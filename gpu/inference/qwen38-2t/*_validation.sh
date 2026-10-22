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

echo "[$(date)] ==================== Starting validation... ===================="

FRONTEND_POD=$(kubectl get pod -l 'nvidia.com/dynamo-component-type=frontend' -o jsonpath='{.items[0].metadata.name}')
echo "Waiting for frontend pod ${FRONTEND_POD} to be Ready..."
kubectl wait --for=condition=Ready "pod/${FRONTEND_POD}" --timeout=1800s

echo "Setting up port-forwarding to svc/qwen3-8-2-4t-a4-disagg-frontend on port 8000..."
kubectl port-forward svc/qwen3-8-2-4t-a4-disagg-frontend 8000:8000 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "${PORT_FORWARD_PID}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Polling endpoint and model registration readiness..."
LIMIT=300
count=0
until curl -sf http://127.0.0.1:8000/v1/models | grep -q "Qwen3.8-2.4T-A95B-NVFP4"; do
  if [[ "${count}" -ge "${LIMIT}" ]]; then
    echo "Timeout waiting for model endpoint to become healthy." >&2
    exit 1
  fi
  if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  sleep 2
  count=$((count + 1))
done

echo "Executing test query to nvidia/Qwen3.8-2.4T-A95B-NVFP4..."
RESPONSE=$(curl -s http://127.0.0.1:8000/v1/chat/completions \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Qwen3.8-2.4T-A95B-NVFP4",
    "messages": [{"role": "user", "content": "Explain KV-cache disaggregation in one sentence."}],
    "max_tokens": 64
  }')

echo "Verifying JSON completion structure..."
if echo "${RESPONSE}" | grep -q '"object": *"chat.completion"'; then
  echo "Chat completion validation succeeded!"
else
  echo "Validation Failed! Expected chat.completion JSON structure. Response was:" >&2
  echo "${RESPONSE}" >&2
  exit 1
fi

if [[ "${SKIP_BENCHMARK:-false}" != "true" && -f "benchmark.log" ]]; then
  echo "Verifying benchmark output from benchmark.log..."
  if grep -q "Serving Benchmark Result" benchmark.log && grep -q "Successful requests:" benchmark.log; then
    echo "Benchmark validation succeeded!"
  else
    echo "Validation Failed! Expected 'Serving Benchmark Result' in benchmark.log:" >&2
    cat benchmark.log >&2
    exit 1
  fi
fi

echo "[$(date)] ==================== Validation passed! ===================="
