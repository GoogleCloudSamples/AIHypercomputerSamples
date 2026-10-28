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
  echo "[$(date)] SKIP_BENCHMARK is true; skipping 8k/1k benchmark."
  exit 0
fi

if [[ -z "${VLLM_IMAGE:-}" || "${VLLM_IMAGE}" == "YOUR_VLLM_TPU_IMAGE" ]]; then
  export VLLM_IMAGE="vllm/vllm-torchtpu:v0.29.0@sha256:3976ccc1a69ffd361e0a7d2831fe317f6b685636014f426321a39ae02f8da0dc"
fi

echo "[$(date)] ==================== Starting ${MODEL_NAME} 8k/1k benchmark (${BENCHMARK_MANIFEST})... ===================="
kubectl delete pod "${BENCHMARK_POD}" --ignore-not-found

if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_benchmark_apply_v6]
  envsubst '$VLLM_IMAGE' < "qwen3-benchmark-8k1k.yaml" | kubectl apply -f -
  # [END hypercomputer_tpu_infer_qwen3_5_397b_benchmark_apply_v6]
else
  # [START hypercomputer_tpu_infer_qwen3_5_397b_benchmark_apply]
  envsubst '$VLLM_IMAGE' < "qwen3_5-benchmark-8k1k.yaml" | kubectl apply -f -
  # [END hypercomputer_tpu_infer_qwen3_5_397b_benchmark_apply]
fi

echo "Waiting for benchmark pod ${BENCHMARK_POD} to start running..."
TIMEOUT=600
ELAPSED=0
while true; do
  PHASE=$(kubectl get pod "${BENCHMARK_POD}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  if [[ "${PHASE}" == "Running" || "${PHASE}" == "Succeeded" ]]; then
    break
  fi
  if [[ "${PHASE}" == "Failed" ]]; then
    echo "Benchmark pod failed to start!" >&2
    kubectl describe pod "${BENCHMARK_POD}" >&2
    exit 1
  fi
  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo "Timeout waiting for benchmark pod ${BENCHMARK_POD} to start." >&2
    kubectl describe pod "${BENCHMARK_POD}" >&2
    exit 1
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo "Streaming benchmark logs..."
kubectl logs -f "${BENCHMARK_POD}" &
LOG_PID=$!

cleanup_logs() {
  kill "${LOG_PID}" 2>/dev/null || true
}
trap cleanup_logs EXIT

if ! kubectl wait --for=jsonpath='{.status.phase}'=Succeeded --timeout=7200s "pod/${BENCHMARK_POD}"; then
  echo "Benchmark pod ${BENCHMARK_POD} did not succeed within 120 minutes!" >&2
  kubectl describe pod "${BENCHMARK_POD}" >&2
  kubectl logs "${BENCHMARK_POD}" --tail=200 >&2 || true
  exit 1
fi

echo "[$(date)] ==================== Benchmark completed successfully! ===================="
