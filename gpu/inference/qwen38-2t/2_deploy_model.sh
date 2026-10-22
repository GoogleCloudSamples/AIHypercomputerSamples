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

if kubectl get dynamographdeployment qwen3-8-2-4t-a4-disagg >/dev/null 2>&1; then
  echo "Deleting existing DynamoGraphDeployment qwen3-8-2-4t-a4-disagg before redeploying..."
  kubectl delete dynamographdeployment qwen3-8-2-4t-a4-disagg --ignore-not-found
  kubectl wait --for=delete pod -l nvidia.com/dynamo-graph-deployment-name=qwen3-8-2-4t-a4-disagg --timeout=300s 2>/dev/null || true
fi

MANIFEST="qwen3.8-2.4t-nvfp4-multihost-a4.yaml"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "Error: Workload manifest '${MANIFEST}' not found in $(pwd)." >&2
  exit 1
fi
echo "[$(date)] ==================== Deploying Qwen 3.8 2.4T multihost server... ===================="
# [START hypercomputer_gpu_infer_qwen38_2t_deploy]
kubectl apply -f qwen3.8-2.4t-nvfp4-multihost-a4.yaml
# [END hypercomputer_gpu_infer_qwen38_2t_deploy]

echo "Waiting for Qwen 3.8 2.4T frontend, prefill, and decode pods to be created..."
TIMEOUT=600
ELAPSED=0
while true; do
  PODS=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "^qwen3-8-2-4t-a4-disagg" || true)
  if echo "${PODS}" | grep -q "frontend" && echo "${PODS}" | grep -q "prefill-ldr" && echo "${PODS}" | grep -q "decode-ldr"; then
    break
  fi
  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo "Timeout waiting for qwen3-8-2-4t-a4-disagg pods to be created!" >&2
    kubectl get pods >&2
    exit 1
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

FRONTEND_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*frontend" | head -n 1)
PREFILL_LDR_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*prefill-ldr" | head -n 1)
DECODE_LDR_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*decode-ldr" | head -n 1)

echo "Created leader/frontend pods:"
echo "  Frontend:    ${FRONTEND_POD}"
echo "  Prefill Ldr: ${PREFILL_LDR_POD}"
echo "  Decode Ldr:  ${DECODE_LDR_POD}"

echo "Waiting for pods to enter Running phase..."
for pod in $(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg"); do
  if ! kubectl wait --for=jsonpath='{.status.phase}'=Running "pod/${pod}" --timeout=1800s; then
    echo "Pod ${pod} failed to enter Running phase within 30 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    exit 1
  fi
done

echo "Streaming decode-ldr pod logs while waiting for pods to become Ready..."
kubectl logs -f "${DECODE_LDR_POD}" &
LOG_PID=$!

cleanup_logs() {
  kill "${LOG_PID}" 2>/dev/null || true
}
trap cleanup_logs EXIT

# [START hypercomputer_gpu_infer_qwen38_2t_deploy_wait]
for pod in "${FRONTEND_POD}" "${PREFILL_LDR_POD}" "${DECODE_LDR_POD}"; do
  if ! kubectl wait --for=condition=Ready "pod/${pod}" --timeout=7200s; then
    echo "Pod ${pod} failed to become Ready within 120 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    kubectl logs "${pod}" --tail=200 >&2 || true
    exit 1
  fi
done
# [END hypercomputer_gpu_infer_qwen38_2t_deploy_wait]

echo "[$(date)] ==================== Qwen 3.8 2.4T deployment is Ready! ===================="
