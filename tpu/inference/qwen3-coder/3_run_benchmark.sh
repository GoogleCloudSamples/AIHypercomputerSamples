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

if [ "${ACCELERATOR_TYPE}" == "v7x" ]; then
# [START hypercomputer_tpu_infer_qwen3_coder_run_benchmark]
kubectl exec deployment/sglang-router -- python3 -m sglang.bench_serving \
  --backend sglang \
  --base-url http://localhost:8000 \
  --model Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8 \
  --dataset-name random \
  --random-input-len 1024 \
  --random-output-len 1024 \
  --random-range-ratio 1.0 \
  --num-prompts 256 \
  --max-concurrency 64
# [END hypercomputer_tpu_infer_qwen3_coder_run_benchmark]
elif [ "${ACCELERATOR_TYPE}" == "v6e" ]; then
# [START hypercomputer_tpu_infer_qwen3_coder_run_benchmark_v6e]
kubectl exec deployment/sglang-router -- python3 -m sglang.bench_serving \
  --backend sglang \
  --base-url http://localhost:8000 \
  --model Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8 \
  --dataset-name random \
  --random-input-len 1024 \
  --random-output-len 1024 \
  --random-range-ratio 1.0 \
  --num-prompts 256 \
  --max-concurrency 256
# [END hypercomputer_tpu_infer_qwen3_coder_run_benchmark_v6e]
else
  echo "Unsupported ACCELERATOR_TYPE: ${ACCELERATOR_TYPE}"
  exit 1
fi
