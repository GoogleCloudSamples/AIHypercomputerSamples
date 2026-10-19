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

if [[ -z "${VLLM_IMAGE:-}" || "${VLLM_IMAGE}" == "YOUR_VLLM_IMAGE" ]]; then
  export VLLM_IMAGE="us-central1-docker.pkg.dev/hdx-ext-uxr/test-images/torchtpu-vllm-prod:nightly-20260805"
fi

BENCHMARK_JOB="vllm-qwen3-5-397b-pd-disagg-v7x-tester"

echo "[$(date)] ==================== Starting Qwen 3.5 397B PD-Disaggregation 8k/1k benchmark... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_benchmark_apply]
envsubst '${VLLM_IMAGE}' < v7x_qwen3_5_benchmark_multihost_slice.yaml | kubectl apply -f -
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_benchmark_apply]

echo "Waiting for benchmark pod to be created and start running..."
pod_creation_timeout=300
elapsed=0
until [[ -n "$(kubectl get pods -l "job-name=${BENCHMARK_JOB}" --no-headers 2>/dev/null)" ]]; do
  if [[ "${elapsed}" -ge "${pod_creation_timeout}" ]]; then
    echo "Error: Timed out after ${pod_creation_timeout}s waiting for ${BENCHMARK_JOB} pod to be created." >&2
    kubectl describe "job/${BENCHMARK_JOB}" >&2 || true
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
if kubectl wait --for=condition=Ready pod -l "job-name=${BENCHMARK_JOB}" --timeout=600s; then
  kubectl logs -f "job/${BENCHMARK_JOB}" &
  LOG_PID=$!
  cleanup_logs() {
    kill "${LOG_PID}" 2>/dev/null || true
  }
  trap cleanup_logs EXIT
fi

if ! kubectl wait --for=condition=Complete --timeout=18000s "job/${BENCHMARK_JOB}"; then
  echo "Error: Benchmark job ${BENCHMARK_JOB} failed or timed out!" >&2
  kubectl describe "job/${BENCHMARK_JOB}" >&2 || true
  kubectl get pods -l "job-name=${BENCHMARK_JOB}" -o wide >&2 || true
  kubectl logs "job/${BENCHMARK_JOB}" --tail=200 >&2 || true
  exit 1
fi

echo "[$(date)] ==================== Benchmark completed successfully! ===================="
