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

echo "[$(date)] ==================== Setting up port forwarding to svc/qwen3-8-2-4t-a4-disagg-frontend... ===================="
kubectl port-forward svc/qwen3-8-2-4t-a4-disagg-frontend 8000:8000 >/dev/null 2>&1 &
port_forward_pid=$!

cleanup() {
  kill "${port_forward_pid}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for port forwarding and model registration to be ready..."
timeout=600
interval=2
elapsed=0
until curl -sf http://127.0.0.1:8000/v1/models | grep -q "Qwen3.8-2.4T-A95B-NVFP4"; do
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

echo "[$(date)] ==================== Sending chat completion request to Qwen 3.8 2.4T... ===================="
echo "=== Request ==="
cat << 'EOF' | jq .
{
  "model": "nvidia/Qwen3.8-2.4T-A95B-NVFP4",
  "messages": [{"role": "user", "content": "Explain KV-cache disaggregation in one sentence."}],
  "max_tokens": 64
}
EOF

echo "=== Response ==="
# [START hypercomputer_gpu_infer_qwen38_2t_interact]
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Qwen3.8-2.4T-A95B-NVFP4",
    "messages": [{"role": "user", "content": "Explain KV-cache disaggregation in one sentence."}],
    "max_tokens": 64
  }' | jq .
# [END hypercomputer_gpu_infer_qwen38_2t_interact]
echo "[$(date)] ==================== Interaction with the model finished. ===================="
