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

if [[ -z "${VLLM_IMAGE:-}" || "${VLLM_IMAGE}" == "YOUR_VLLM_TPU_IMAGE" ]]; then
  export VLLM_IMAGE="vllm/vllm-torchtpu:v0.29.0@sha256:3976ccc1a69ffd361e0a7d2831fe317f6b685636014f426321a39ae02f8da0dc"
fi

if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3-30B-A3B-FP8}"
  SERVER_MANIFEST="${SERVER_MANIFEST:-qwen3_server.yaml}"
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vllm-qwen3}"
else
  MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3.5-397B-A17B-FP8}"
  SERVER_MANIFEST="${SERVER_MANIFEST:-qwen3_5_server.yaml}"
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vllm-qwen3-5}"
fi

echo "[$(date)] ==================== Deploying the vLLM ${MODEL_NAME} server (${SERVER_MANIFEST})... ===================="
if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_deploy_v6]
  envsubst '$VLLM_IMAGE' < "qwen3_server.yaml" | kubectl apply -f -
  # [END hypercomputer_tpu_infer_qwen3_5_397b_deploy_v6]
else
  # [START hypercomputer_tpu_infer_qwen3_5_397b_deploy]
  envsubst '$VLLM_IMAGE' < "qwen3_5_server.yaml" | kubectl apply -f -
  # [END hypercomputer_tpu_infer_qwen3_5_397b_deploy]
fi

echo "Waiting for the ${DEPLOYMENT_NAME} pod to be created..."
TIMEOUT=300
ELAPSED=0
until kubectl get pods -l "app=${DEPLOYMENT_NAME}" 2>/dev/null | grep -q "${DEPLOYMENT_NAME}"; do
  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo "Timeout waiting for ${DEPLOYMENT_NAME} pod to be created! Describing deployment:" >&2
    kubectl describe deployment "${DEPLOYMENT_NAME}" >&2
    exit 1
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo "Waiting for the ${DEPLOYMENT_NAME} pod to start running..."
if ! kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l "app=${DEPLOYMENT_NAME}" --timeout=900s; then
  echo "Pod failed to start running within 15 minutes! Describing pod:" >&2
  kubectl describe pod -l "app=${DEPLOYMENT_NAME}" >&2
  exit 1
fi

echo "Streaming server logs while waiting for deployment/${DEPLOYMENT_NAME} to become Available..."
kubectl logs "deployment/${DEPLOYMENT_NAME}" -c vllm-tpu -f &
LOG_PID=$!

cleanup_logs() {
  kill "${LOG_PID}" 2>/dev/null || true
}
trap cleanup_logs EXIT

if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_deploy_wait_v6]
  if ! kubectl wait \
      --for=condition=Available \
      --timeout=7200s deployment/vllm-qwen3; then
    echo "Deployment vllm-qwen3 failed to become Available within 120 minutes!" >&2
    kubectl describe pod -l app=vllm-qwen3 >&2
    kubectl logs deployment/vllm-qwen3 -c vllm-tpu --tail=200 >&2 || true
    exit 1
  fi
  # [END hypercomputer_tpu_infer_qwen3_5_397b_deploy_wait_v6]
else
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
fi

echo "[$(date)] ==================== Server deployment is Ready! ===================="
