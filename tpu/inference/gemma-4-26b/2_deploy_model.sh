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

: "${VLLM_IMAGE:?VLLM_IMAGE must be set (see 0_env.sh)}"

# [START hypercomputer_tpu_infer_gemma4_26b_deploy]
MANIFEST="gemma4-26b-multihost-v6e-2x4.yaml"
echo "Applying LeaderWorkerSet (retrying if webhook is not fully ready)..."
MAX_ATTEMPTS=12
attempt=1
until envsubst '$RESERVATION_NAME $ZONE $VLLM_IMAGE' < "${MANIFEST}" | kubectl apply -f -; do
  if [ "${attempt}" -ge "${MAX_ATTEMPTS}" ]; then
    echo "Error: failed to apply ${MANIFEST} after ${MAX_ATTEMPTS} attempts." >&2
    exit 1
  fi
  echo "Webhook not ready yet, retrying in 5 seconds (attempt ${attempt}/${MAX_ATTEMPTS})..."
  attempt=$((attempt + 1))
  sleep 5
done
# [END hypercomputer_tpu_infer_gemma4_26b_deploy]

echo "Deploying the model and tracking progress..."
# [START hypercomputer_tpu_infer_gemma4_26b_deploy_wait]
(
  LIMIT=60
  count=0
  until kubectl get pod -l role=leader -o name | grep -q "vllm-tpu"; do
    if [ "${count}" -ge "${LIMIT}" ]; then
      echo "Error: timeout waiting for leader pod to be created." >&2
      exit 1
    fi
    echo "Waiting for leader pod to be created..."
    sleep 5
    count=$((count + 1))
  done
  # Wait up to 20 minutes for the pod to start running (TPU nodes take a while to boot)
  echo "Waiting for pod to be scheduled and running..."
  if ! kubectl wait --for=jsonpath='{.status.phase}'=Running --timeout=1200s pod -l role=leader; then
    echo "Pod failed to start running within 20 minutes! Here are the events:" >&2
    kubectl describe pod -l role=leader
    exit 1
  fi
  echo "Pod is running. Streaming logs while waiting for it to become Ready (this includes model download)..."
  # Stream logs in the background so the user can see what's happening
  kubectl logs -f -l role=leader &
  LOG_PID=$!
  trap 'kill "${LOG_PID}" 2>/dev/null || true; wait "${LOG_PID}" 2>/dev/null || true' EXIT
  if ! kubectl wait --for=condition=Ready --timeout=3600s pod -l role=leader; then
    echo "Pod failed to become Ready within 60 minutes!" >&2
    kubectl describe pod -l role=leader
    exit 1
  fi
  echo "Pod is Ready!"
)
# [END hypercomputer_tpu_infer_gemma4_26b_deploy_wait]
