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

if [[ "${SKIP_BENCHMARK:-false}" == "true" ]]; then
  echo "[$(date)] SKIP_BENCHMARK is true; skipping benchmark."
  exit 0
fi

echo "[$(date)] ==================== Starting Llama 3.1 405B 1k/1k benchmark... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_benchmark]
ROUTER_POD=$(kubectl get pod -l 'nvidia.com/dynamo-component-type=frontend' -o jsonpath='{.items[0].metadata.name}')

kubectl exec "${ROUTER_POD}" -- python3 -m sglang.bench_serving \
  --backend sglang-oai-chat \
  --base-url http://localhost:8000 \
  --model nvidia/Llama-3.1-405B-Instruct-FP8 \
  --dataset-name random \
  --random-input-len 1024 \
  --random-output-len 1024 \
  --random-range-ratio 1.0 \
  --num-prompts 2048 \
  --max-concurrency 512 \
  --warmup-requests 10 | tee benchmark.log
# [END hypercomputer_gpu_infer_llama3_405b_benchmark]

echo "[$(date)] ==================== Benchmark completed successfully! ===================="
