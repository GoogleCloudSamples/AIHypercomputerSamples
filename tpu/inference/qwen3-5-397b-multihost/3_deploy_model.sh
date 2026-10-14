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

JOBSET_NAME="vllm-qwen3-5-397b-pd-disagg-v7x"

echo "[$(date)] ==================== Deploying the vLLM Qwen 3.5 397B PD-Disaggregated server JobSet... ===================="
for i in {1..12}; do
  if envsubst '$GCS_BUCKET' < v7x_qwen3_5_server_multihost_slice.yaml | kubectl apply -f -; then
    break
  fi
  echo "JobSet webhook not ready yet, retrying in 5 seconds..."
  sleep 5
done

echo "Waiting for prefill, decode, and proxy pods to be created..."
until [[ $(kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" --no-headers 2>/dev/null | wc -l) -ge 5 ]]; do
  sleep 5
done

echo "Waiting for all pods in JobSet ${JOBSET_NAME} to be scheduled and initialized..."
if ! kubectl wait --for=condition=Initialized --timeout=1800s pod -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}"; then
  echo "Error: Pods in JobSet ${JOBSET_NAME} failed to initialize within 30 minutes!" >&2
  kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" -o wide >&2 || true
  kubectl describe pod -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" >&2 || true
  exit 1
fi

echo "Waiting for all pods in JobSet ${JOBSET_NAME} to reach Ready state..."
if ! kubectl wait --for=condition=Ready --timeout=1800s pod -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}"; then
  echo "Error: Pods in JobSet ${JOBSET_NAME} failed to reach Ready state within 30 minutes!" >&2
  kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" -o wide >&2 || true
  kubectl describe pod -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" >&2 || true
  exit 1
fi

echo "Streaming prefill and decode head node logs while waiting for vLLM compilation and startup (~30-45 minutes)..."
kubectl logs "${JOBSET_NAME}-prefill-0-0" -f --prefix=true &
PREFILL_LOG_PID=$!
kubectl logs "${JOBSET_NAME}-decode-0-0" -f --prefix=true &
DECODE_LOG_PID=$!

cleanup_logs() {
  kill "${PREFILL_LOG_PID}" "${DECODE_LOG_PID}" 2>/dev/null || true
}
trap cleanup_logs EXIT

TIMEOUT=7200
INTERVAL=15
ELAPSED=0
PREFILL_READY=false
DECODE_READY=false

while [[ "${PREFILL_READY}" != "true" || "${DECODE_READY}" != "true" ]]; do
  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo "Error: Timed out after ${TIMEOUT}s waiting for prefill and decode vLLM servers to finish startup." >&2
    kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" -o wide >&2 || true
    kubectl logs "${JOBSET_NAME}-prefill-0-0" --tail=100 >&2 || true
    kubectl logs "${JOBSET_NAME}-decode-0-0" --tail=100 >&2 || true
    exit 1
  fi

  if kubectl logs "${JOBSET_NAME}-prefill-0-0" --tail=200 2>/dev/null | grep -q "Application startup complete."; then
    PREFILL_READY=true
  fi
  if kubectl logs "${JOBSET_NAME}-decode-0-0" --tail=200 2>/dev/null | grep -q "Application startup complete."; then
    DECODE_READY=true
  fi

  if [[ "${PREFILL_READY}" == "true" && "${DECODE_READY}" == "true" ]]; then
    break
  fi

  sleep "${INTERVAL}"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "[$(date)] ==================== Prefill, Decode, and Proxy servers are up and ready! ===================="
