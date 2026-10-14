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

JOBSET_NAME="vllm-qwen3-5-397b-pd-disagg-v7x"
PROXY_POD="${JOBSET_NAME}-proxy-0-0"
BENCHMARK_JOB="vllm-qwen3-5-397b-pd-disagg-v7x-tester"

echo "Verifying proxy pod ${PROXY_POD} is Ready..."
kubectl wait --for=condition=Ready --timeout=600s "pod/${PROXY_POD}"

echo "Setting up port-forwarding to ${PROXY_POD} on port 10000..."
kubectl port-forward "pod/${PROXY_POD}" 10000:10000 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "${PORT_FORWARD_PID}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Polling disaggregation proxy endpoint readiness..."
LIMIT=60
count=0
until curl -sf http://127.0.0.1:10000/healthcheck >/dev/null; do
  if [[ "${count}" -ge "${LIMIT}" ]]; then
    echo "Timeout waiting for disaggregation proxy endpoint to become healthy." >&2
    exit 1
  fi
  if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    echo "Error: Port forwarding failed to start or died unexpectedly." >&2
    exit 1
  fi
  sleep 2
  count=$((count + 1))
done

echo "Executing test chat completion query to Qwen/Qwen3.5-397B-A17B-FP8 via PD-Disaggregation proxy..."
RESPONSE=$(curl -s http://127.0.0.1:10000/v1/chat/completions \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "model": "Qwen/Qwen3.5-397B-A17B-FP8",
        "messages": [
            {"role": "user", "content": "Hello! Tell me a short joke."}
        ],
        "max_tokens": 64,
        "temperature": 0.7
    }')

echo "Verifying JSON completion structure..."
if echo "${RESPONSE}" | grep -q '"object": *"chat.completion"'; then
  echo "Chat completion validation succeeded!"
else
  echo "Validation Failed! Expected chat.completion JSON structure. Response was:" >&2
  echo "${RESPONSE}" >&2
  exit 1
fi

if [[ "${SKIP_BENCHMARK:-false}" != "true" ]] && kubectl get job "${BENCHMARK_JOB}" >/dev/null 2>&1; then
  echo "Verifying benchmark logs from job/${BENCHMARK_JOB}..."
  BENCH_LOGS=$(kubectl logs "job/${BENCHMARK_JOB}")
  if echo "${BENCH_LOGS}" | grep -q "Serving Benchmark Result" && echo "${BENCH_LOGS}" | grep -q "BENCHMARK COMPLETED SUCCESSFULLY"; then
    echo "Benchmark validation succeeded!"
  else
    echo "Validation Failed! Expected 'Serving Benchmark Result' and 'BENCHMARK COMPLETED SUCCESSFULLY' in job/${BENCHMARK_JOB} logs:" >&2
    echo "${BENCH_LOGS}" >&2
    exit 1
  fi
fi

echo "[$(date)] ==================== Validation passed! ===================="
