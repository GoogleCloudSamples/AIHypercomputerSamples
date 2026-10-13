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

echo "[$(date)] ==================== Deploying the vLLM Qwen 3.5 397B server... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_deploy]
kubectl apply -f qwen3_5_server.yaml
# [END hypercomputer_tpu_infer_qwen3_5_397b_deploy]

echo "Waiting for the vllm-qwen3-5 pod to be created..."
until kubectl get pods -l app=vllm-qwen3-5 2>/dev/null | grep -q "vllm-qwen3-5"; do
  sleep 5
done

echo "Waiting for the vllm-qwen3-5 pod to be scheduled and initialized..."
if ! kubectl wait --for=condition=Initialized --timeout=1800s pod -l app=vllm-qwen3-5; then
  echo "Pod failed to initialize within 30 minutes! Describing pod:" >&2
  kubectl describe pod -l app=vllm-qwen3-5 >&2
  exit 1
fi

echo "Streaming server logs while waiting for deployment/vllm-qwen3-5 to become Available..."
kubectl logs deployment/vllm-qwen3-5 -c vllm-tpu -f &
LOG_PID=$!

cleanup_logs() {
  kill "${LOG_PID}" 2>/dev/null || true
}
trap cleanup_logs EXIT

# [START hypercomputer_tpu_infer_qwen3_5_397b_deploy_wait]
if ! kubectl wait \
    --for=condition=Available \
    --timeout=7200s deployment/vllm-qwen3-5; then
  echo "Deployment vllm-qwen3-5 failed to become Available within 120 minutes!" >&2
  kubectl describe pod -l app=vllm-qwen3-5 >&2
  kubectl logs deployment/vllm-qwen3-5 -c vllm-tpu --tail=200 >&2 || true
  exit 1
fi
# [END hypercomputer_tpu_infer_qwen3_5_397b_deploy_wait]

echo "[$(date)] ==================== Server deployment is Ready! ===================="
