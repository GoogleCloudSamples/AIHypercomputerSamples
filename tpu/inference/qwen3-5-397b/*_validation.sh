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

if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vllm-qwen3}"
  SERVICE_NAME="${SERVICE_NAME:-vllm-qwen3-service}"
  MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3-30B-A3B-FP8}"
  BENCHMARK_POD="${BENCHMARK_POD:-qwen3-bench-8k1k}"
else
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vllm-qwen3-5}"
  SERVICE_NAME="${SERVICE_NAME:-vllm-qwen3-5-service}"
  MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3.5-397B-A17B-FP8}"
  BENCHMARK_POD="${BENCHMARK_POD:-qwen3-5-bench-8k1k}"
fi

echo "Waiting for GKE deployment/${DEPLOYMENT_NAME} to be Available..."
kubectl wait \
    --for=condition=Available \
    --timeout=1800s "deployment/${DEPLOYMENT_NAME}"

echo "Setting up port-forwarding to ${SERVICE_NAME} on port 8000..."
kubectl port-forward "service/${SERVICE_NAME}" 8000:8000 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "${PORT_FORWARD_PID}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Polling endpoint readiness..."
LIMIT=300
count=0
until curl -s http://127.0.0.1:8000/health >/dev/null || curl -s http://127.0.0.1:8000/ping >/dev/null; do
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

echo "Executing test query to ${MODEL_NAME}..."
RESPONSE=$(curl -s http://127.0.0.1:8000/v1/chat/completions \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL_NAME}\",
        \"messages\": [
            {\"role\": \"user\", \"content\": \"Hello! Tell me a joke.\"}
        ],
        \"max_tokens\": 512,
        \"temperature\": 0.7
    }")

echo "Verifying JSON completion structure..."
if echo "${RESPONSE}" | grep -q '"object": *"chat.completion"'; then
  echo "Chat completion validation succeeded!"
else
  echo "Validation Failed! Expected chat.completion JSON structure. Response was:" >&2
  echo "${RESPONSE}" >&2
  exit 1
fi

if [[ "${SKIP_BENCHMARK:-false}" != "true" ]] && kubectl get pod "${BENCHMARK_POD}" >/dev/null 2>&1; then
  echo "Verifying benchmark logs from pod/${BENCHMARK_POD}..."
  BENCH_LOGS=$(kubectl logs "${BENCHMARK_POD}")
  if echo "${BENCH_LOGS}" | grep -q "Serving Benchmark Result" && echo "${BENCH_LOGS}" | grep -q "Successful requests:"; then
    echo "Benchmark validation succeeded!"
  else
    echo "Validation Failed! Expected 'Serving Benchmark Result' in ${BENCHMARK_POD} logs:" >&2
    echo "${BENCH_LOGS}" >&2
    exit 1
  fi
fi

echo "[$(date)] ==================== Validation passed! ===================="
