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

echo "[$(date)] ==================== Setting up port forwarding to vllm-qwen3-5-service... ===================="
kubectl port-forward service/vllm-qwen3-5-service 8000:8000 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "${PORT_FORWARD_PID}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for port forwarding to be ready..."
TIMEOUT=60
INTERVAL=2
ELAPSED=0
until curl -s http://localhost:8000/health >/dev/null || curl -s http://localhost:8000/ping >/dev/null; do
  if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo "Error: Timeout waiting for port forwarding to be ready." >&2
    exit 1
  fi
  sleep "${INTERVAL}"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "[$(date)] ==================== Sending chat completion request to Qwen 3.5 397B... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_interact]
curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "Qwen/Qwen3.5-397B-A17B-FP8",
        "messages": [
            {"role": "user", "content": "Hello! Tell me a joke."}
        ],
        "max_tokens": 512,
        "temperature": 0.7
    }' | jq .
# [END hypercomputer_tpu_infer_qwen3_5_397b_interact]
echo "[$(date)] ==================== Interaction with the model finished. ===================="
