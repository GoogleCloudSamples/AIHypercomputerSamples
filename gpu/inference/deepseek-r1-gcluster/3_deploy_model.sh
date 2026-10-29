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

LEADER_SELECTOR="app=vllm-r1,role=leader"
WORKER_SELECTOR="app=vllm-r1,role=worker"

echo "Deploying the vLLM server..."
# [START hypercomputer_gpu_infer_deepseek_r1_deploy]
envsubst '$MODEL_BUCKET' < deepseek_r1_server.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek_r1_deploy]

LIMIT=60
count=0
until kubectl get pod -l "${LEADER_SELECTOR}" -o name | grep -q "pod/" && \
      kubectl get pod -l "${WORKER_SELECTOR}" -o name | grep -q "pod/"; do
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for the leader and worker pods to be created." >&2
    exit 1
  fi
  echo "Waiting for the leader and worker pods to be created..."
  sleep 5
  count=$((count + 1))
done

echo "Waiting for the leader and worker pods to be running..."
for selector in "${LEADER_SELECTOR}" "${WORKER_SELECTOR}"; do
  if ! kubectl wait --for=jsonpath='{.status.phase}'=Running --timeout=1200s pod -l "${selector}"; then
    echo "Pods (${selector}) failed to start running within 20 minutes! Here are the events:" >&2
    kubectl describe pod -l "${selector}"
    exit 1
  fi
done

echo "Pods are running. Streaming leader logs while the server starts (~15-20 minutes)..."
kubectl logs -f -l "${LEADER_SELECTOR}" -c vllm-leader --tail=-1 &
LOG_PID=$!
trap 'kill "${LOG_PID}" 2>/dev/null || true' EXIT

# Wait up to 45 minutes for the vLLM server health endpoint to respond.
LIMIT=270
count=0
while true; do
  LEADER_POD=$(kubectl get pod -l "${LEADER_SELECTOR}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "${LEADER_POD}" ] && kubectl exec "${LEADER_POD}" -c vllm-leader -- \
      python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health', timeout=5)" \
      >/dev/null 2>&1; then
    break
  fi
  if [ "$(kubectl get jobset vllm-r1 -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}')" = "True" ]; then
    echo "Error: the vllm-r1 JobSet failed." >&2
    kubectl describe jobset vllm-r1
    exit 1
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for the vLLM server to become healthy." >&2
    kubectl describe pod -l "${LEADER_SELECTOR}"
    exit 1
  fi
  sleep 10
  count=$((count + 1))
done

echo "The vLLM server is ready!"
