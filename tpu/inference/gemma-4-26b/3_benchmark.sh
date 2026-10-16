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

LEADER_POD="vllm-tpu-gemma4-26b-0"
NUM_PROMPTS=250
BENCHMARK_LOG="$(mktemp)"
trap 'rm -f "${BENCHMARK_LOG}"' EXIT

echo "Waiting for the leader pod to be Ready..."
if ! kubectl wait --for=condition=Ready --timeout=600s "pod/${LEADER_POD}"; then
  echo "Error: leader pod ${LEADER_POD} is not Ready." >&2
  kubectl describe pod "${LEADER_POD}"
  exit 1
fi

echo "Running benchmark inside the leader pod..."
{
# [START hypercomputer_tpu_infer_gemma4_26b_benchmark_run]
kubectl exec vllm-tpu-gemma4-26b-0 -- vllm bench serve \
  --backend openai-chat \
  --endpoint /v1/chat/completions \
  --model google/gemma-4-26B-A4B-it \
  --host localhost \
  --port 8000 \
  --dataset-name random \
  --num-prompts 250 \
  --random-input-len 1024 \
  --random-output-len 1024 \
  --max-concurrency 128
# [END hypercomputer_tpu_infer_gemma4_26b_benchmark_run]
} 2>&1 | tee "${BENCHMARK_LOG}"

COMPLETED=$(awk -F: '/^Successful requests:/ {gsub(/ /, "", $2); print $2}' "${BENCHMARK_LOG}")
if [ "${COMPLETED:-0}" -ne "${NUM_PROMPTS}" ]; then
  echo "Benchmark failed: only ${COMPLETED:-0}/${NUM_PROMPTS} requests completed." >&2
  exit 1
fi
echo "Benchmark succeeded: ${COMPLETED}/${NUM_PROMPTS} requests completed."
