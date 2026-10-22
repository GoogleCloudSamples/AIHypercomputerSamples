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

kubectl port-forward service/vllm-r1-leader 8080:8080 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for port forwarding to be ready..."
LIMIT=60
count=0
until curl -sf http://localhost:8080/health >/dev/null; do
  if ! kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for the model server health endpoint." >&2
    exit 1
  fi
  sleep 1
  count=$((count + 1))
done

echo "Sending a chat completion request to the model..."
RESPONSE=$(curl -sf http://localhost:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "deepseek-ai/DeepSeek-R1",
        "messages": [
            {"role": "user", "content": "Explain tensor parallelism in one sentence."}
        ],
        "max_tokens": 100,
        "temperature": 0.6
    }')
echo "${RESPONSE}" | jq .

if echo "${RESPONSE}" | jq -e '.choices[0].message.content | length > 0' >/dev/null; then
  echo "Validation succeeded: model returned a non-empty completion."
else
  echo "Validation failed: response did not contain a completion." >&2
  exit 1
fi
