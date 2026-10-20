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

MANIFEST="llama3.1-405b-singlehost-a4.yaml"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "Error: Workload manifest '${MANIFEST}' not found in $(pwd)." >&2
  exit 1
fi

echo "[$(date)] ==================== Deploying Llama 3.1 405B PD-disaggregated server... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_deploy]
kubectl apply -f llama3.1-405b-singlehost-a4.yaml
# [END hypercomputer_gpu_infer_llama3_405b_deploy]

echo "Waiting for Llama 3.1 405B frontend, prefill, and decode pods to be created..."
TIMEOUT=600
ELAPSED=0
while true; do
  PODS=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "^llama3-405b-a4-disagg" || true)
  if echo "${PODS}" | grep -q "frontend" && echo "${PODS}" | grep -q "prefill" && echo "${PODS}" | grep -q "decode"; then
    break
  fi
  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo "Timeout waiting for llama3-405b-a4-disagg pods to be created!" >&2
    kubectl get pods >&2
    exit 1
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

FRONTEND_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^llama3-405b-a4-disagg.*frontend" | head -n 1)
PREFILL_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^llama3-405b-a4-disagg.*prefill" | head -n 1)
DECODE_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^llama3-405b-a4-disagg.*decode" | head -n 1)

echo "Created pods:"
echo "  Frontend: ${FRONTEND_POD}"
echo "  Prefill:  ${PREFILL_POD}"
echo "  Decode:   ${DECODE_POD}"

echo "Waiting for prefill and decode pods to enter Running phase..."
for pod in "${FRONTEND_POD}" "${PREFILL_POD}" "${DECODE_POD}"; do
  if ! kubectl wait --for=jsonpath='{.status.phase}'=Running "pod/${pod}" --timeout=1800s; then
    echo "Pod ${pod} failed to enter Running phase within 30 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    exit 1
  fi
done

echo "Streaming decode pod logs while waiting for all pods to become Ready..."
kubectl logs -f "${DECODE_POD}" &
LOG_PID=$!

cleanup_logs() {
  kill "${LOG_PID}" 2>/dev/null || true
}
trap cleanup_logs EXIT

# [START hypercomputer_gpu_infer_llama3_405b_deploy_wait]
for pod in "${FRONTEND_POD}" "${PREFILL_POD}" "${DECODE_POD}"; do
  if ! kubectl wait --for=condition=Ready "pod/${pod}" --timeout=3600s; then
    echo "Pod ${pod} failed to become Ready within 60 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    kubectl logs "${pod}" --tail=200 >&2 || true
    exit 1
  fi
done
# [END hypercomputer_gpu_infer_llama3_405b_deploy_wait]

echo "[$(date)] ==================== Llama 3.1 405B deployment is Ready! ===================="
