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

NUM_PROMPTS=1280
BENCHMARK_LOG="$(mktemp)"
trap 'rm -f "${BENCHMARK_LOG}"' EXIT

# Removes any leftover benchmark pod from a previous run (pods are immutable).
prepare_benchmark() {
  local pod="$1"
  kubectl delete pod "${pod}" --ignore-not-found
}

# Waits for the benchmark pod to finish, streams its logs and verifies that
# all requests completed successfully.
wait_for_benchmark() {
  local pod="$1"
  local phase=""
  local count=0

  echo "Waiting for the benchmark pod ${pod} to start..."
  until phase=$(kubectl get pod "${pod}" -o jsonpath='{.status.phase}') && \
        [ -n "${phase}" ] && [ "${phase}" != "Pending" ]; do
    if [ "${count}" -ge 60 ]; then
      echo "Error: timeout waiting for the benchmark pod ${pod} to start." >&2
      kubectl describe pod "${pod}"
      exit 1
    fi
    sleep 10
    count=$((count + 1))
  done

  echo "Streaming logs of ${pod}..."
  kubectl logs -f "${pod}" -c benchmark 2>&1 | tee "${BENCHMARK_LOG}"

  count=0
  until phase=$(kubectl get pod "${pod}" -o jsonpath='{.status.phase}') && \
        { [ "${phase}" = "Succeeded" ] || [ "${phase}" = "Failed" ]; }; do
    if [ "${count}" -ge 30 ]; then
      echo "Error: timeout waiting for the benchmark pod ${pod} to finish." >&2
      exit 1
    fi
    sleep 10
    count=$((count + 1))
  done

  if [ "${phase}" != "Succeeded" ]; then
    echo "Benchmark failed: pod ${pod} finished in phase ${phase}." >&2
    exit 1
  fi

  local completed
  completed=$(awk -F: '/^Successful requests:/ {gsub(/ /, "", $2); print $2}' "${BENCHMARK_LOG}")
  if [ "${completed:-0}" -ne "${NUM_PROMPTS}" ]; then
    echo "Benchmark ${pod} failed: only ${completed:-0}/${NUM_PROMPTS} requests completed." >&2
    exit 1
  fi
  echo "Benchmark ${pod} succeeded: ${completed}/${NUM_PROMPTS} requests completed."
}

echo "Running the 8k/1k benchmark (~15 minutes)..."
prepare_benchmark vllm-bench-8k-1k
# [START hypercomputer_gpu_infer_deepseek_r1_benchmark_8k_1k_run]
envsubst '$MODEL_BUCKET' < deepseek_r1_8k_1k.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek_r1_benchmark_8k_1k_run]
wait_for_benchmark vllm-bench-8k-1k

echo "Benchmark succeeded."
