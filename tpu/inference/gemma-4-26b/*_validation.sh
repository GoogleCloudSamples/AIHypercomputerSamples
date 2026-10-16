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

kubectl port-forward service/vllm-service 8000:8000 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for port forwarding to be ready..."
LIMIT=60
count=0
until curl -sf http://localhost:8000/health >/dev/null; do
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

check_completion() {
  local name="$1"
  local response="$2"
  echo "${response}" | jq .
  if echo "${response}" | jq -e '.choices[0].message.content | length > 0' >/dev/null; then
    echo "${name} request succeeded: model returned a non-empty completion."
  else
    echo "Validation failed: ${name} response did not contain a completion." >&2
    exit 1
  fi
}

echo "Sending text request to the model..."
TEXT_RESPONSE=$(curl -sf http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "google/gemma-4-26B-A4B-it",
        "messages": [{"role": "user", "content": "Explain Mixture of Experts in 2 sentences."}],
        "max_tokens": 128
    }')
check_completion "Text" "${TEXT_RESPONSE}"

echo "Sending image request to the model..."
IMAGE_RESPONSE=$(curl -sf http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "google/gemma-4-26B-A4B-it",
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?auto=format&fit=crop&w=800&q=80"
                        }
                    },
                    {
                        "type": "text",
                        "text": "Describe the image above"
                    }
                ]
            }
        ],
        "max_tokens": 300,
        "temperature": 0.0,
        "top_p": 1.0
    }')
check_completion "Image" "${IMAGE_RESPONSE}"

echo "Validation succeeded: text and image requests returned non-empty completions."
