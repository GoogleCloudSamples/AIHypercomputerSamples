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

echo "[$(date)] ==================== Setting up port forwarding to svc/llama3-405b-a4-disagg-frontend... ===================="
kubectl port-forward svc/llama3-405b-a4-disagg-frontend 8000:8000 >/dev/null 2>&1 &
port_forward_pid=$!

cleanup() {
  kill "${port_forward_pid}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for port forwarding to be ready..."
timeout=120
interval=2
elapsed=0
until curl -s http://localhost:8000/health >/dev/null || curl -s http://localhost:8000/v1/models >/dev/null; do
  if ! kill -0 "${port_forward_pid}" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  if [[ "${elapsed}" -ge "${timeout}" ]]; then
    echo "Error: Timeout waiting for port forwarding to be ready." >&2
    exit 1
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
done

echo "[$(date)] ==================== Sending chat completion request to Llama 3.1 405B... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_interact]
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Llama-3.1-405B-Instruct-FP8",
    "messages": [{"role": "user", "content": "Explain KV-cache disaggregation in one sentence."}],
    "max_tokens": 64
  }' | jq .
# [END hypercomputer_gpu_infer_llama3_405b_interact]
echo "[$(date)] ==================== Interaction with the model finished. ===================="
