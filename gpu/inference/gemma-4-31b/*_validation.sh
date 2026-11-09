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

: "${MODEL_ID:?MODEL_ID must be set (see 0_env.sh)}"

DEPLOYMENT="vllm-gemma4-31b"
SERVICE="vllm-gemma4-31b-service"
POD_SELECTOR="app=vllm-gemma4-31b"
LOCAL_PORT=8000
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"
RESPONSE_FILE="$(mktemp)"
PORT_FORWARD_PID=""

dump_debug_info() {
  local status="$1"
  echo "==================== Debug information ===================="
  kubectl get deployment,pods,service -l "${POD_SELECTOR}" -o wide || true
  kubectl describe deployment "${DEPLOYMENT}" || true
  kubectl describe pods -l "${POD_SELECTOR}" || true
  echo "---- Node GPU driver ----"
  kubectl get nodes -l cloud.google.com/gke-accelerator \
      -L cloud.google.com/gke-accelerator,cloud.google.com/gke-gpu-driver-version || true
  kubectl exec "deployment/${DEPLOYMENT}" -- \
      nvidia-smi --query-gpu=index,name,driver_version,memory.used,memory.total --format=csv || true
  echo "---- Pod logs (last 200 lines) ----"
  kubectl logs -l "${POD_SELECTOR}" --tail=200 || true
  if [ "${status}" -ne 0 ]; then
    echo "---- Previous container logs (last 200 lines) ----"
    kubectl logs -l "${POD_SELECTOR}" --previous --tail=200 || true
  fi
}

on_exit() {
  local status=$?
  if [ -n "${PORT_FORWARD_PID}" ]; then
    kill "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
  dump_debug_info "${status}"
  rm -f "${RESPONSE_FILE}"
  if [ "${status}" -eq 0 ]; then
    echo "Validation succeeded."
  else
    echo "Validation failed." >&2
  fi
  exit "${status}"
}
trap on_exit EXIT

echo "Waiting for deployment/${DEPLOYMENT} to be available..."
kubectl wait --for=condition=Available --timeout=900s "deployment/${DEPLOYMENT}"

echo "Setting up port forwarding to service/${SERVICE} on port ${LOCAL_PORT}..."
kubectl port-forward "service/${SERVICE}" "${LOCAL_PORT}:8000" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

LIMIT=60
count=0
until curl -sf "${BASE_URL}/health" >/dev/null; do
  if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: Timeout waiting for the model server health endpoint." >&2
    exit 1
  fi
  sleep 2
  count=$((count + 1))
done

echo "Checking that the server serves ${MODEL_ID}..."
MODELS=$(curl -sS --fail --max-time 60 "${BASE_URL}/v1/models")
if ! jq -e --arg model "${MODEL_ID}" 'any(.data[]; .id == $model)' <<< "${MODELS}" >/dev/null; then
  echo "Error: ${MODEL_ID} is not in the list of served models:" >&2
  jq . <<< "${MODELS}" >&2 || echo "${MODELS}" >&2
  exit 1
fi

echo "Sending a chat completion request to the model..."
REQUEST=$(jq -n --arg model "${MODEL_ID}" '{
  model: $model,
  messages: [{role: "user", content: "Why is the sky blue? Answer in two sentences."}],
  max_tokens: 128,
  temperature: 0
}')
HTTP_CODE=$(curl -sS --max-time 300 \
    -o "${RESPONSE_FILE}" \
    -w '%{http_code}' \
    -H "Content-Type: application/json" \
    -d "${REQUEST}" \
    "${BASE_URL}/v1/chat/completions")

echo "HTTP status: ${HTTP_CODE}"
jq . "${RESPONSE_FILE}" || cat "${RESPONSE_FILE}"

if [ "${HTTP_CODE}" != "200" ]; then
  echo "Error: the chat completion request returned HTTP ${HTTP_CODE}." >&2
  exit 1
fi

if ! jq -e '.object == "chat.completion"' "${RESPONSE_FILE}" >/dev/null; then
  echo "Error: the response is not a chat completion object." >&2
  exit 1
fi

if ! jq -e '(.choices[0].message.content // "") | gsub("\\s"; "") | length > 0' \
    "${RESPONSE_FILE}" >/dev/null; then
  echo "Error: the response doesn't contain generated text." >&2
  exit 1
fi

echo "Generated text:"
jq -r '.choices[0].message.content' "${RESPONSE_FILE}"
echo "Completion tokens: $(jq -r '.usage.completion_tokens // "unknown"' "${RESPONSE_FILE}")"
