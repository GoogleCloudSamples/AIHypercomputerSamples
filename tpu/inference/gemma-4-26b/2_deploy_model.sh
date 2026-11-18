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

# Pre-flight: make sure the LWS admission webhooks answer reliably before the
# real apply. A server-side dry run goes through mutating/validating webhooks
# without persisting anything. Require several consecutive successes because
# webhook calls are load-balanced across all LWS controller replicas.
echo "Verifying LWS admission webhooks with a server-side dry run..."
REQUIRED_SUCCESSES=3
SUCCESSES=0
for attempt in $(seq 1 30); do
  if envsubst '$RESERVATION_NAME $ZONE $VLLM_IMAGE' < gemma4-26b-multihost-v6e-2x4.yaml \
      | kubectl apply --dry-run=server -f - >/dev/null 2>&1; then
    SUCCESSES=$((SUCCESSES + 1))
    if [ "${SUCCESSES}" -ge "${REQUIRED_SUCCESSES}" ]; then
      echo "LWS admission webhooks are ready."
      break
    fi
  else
    SUCCESSES=0
    echo "  LWS webhook not ready yet (attempt ${attempt}/30), retrying in 5s..."
  fi
  sleep 5
done

if [ "${SUCCESSES}" -lt "${REQUIRED_SUCCESSES}" ]; then
  echo "Error: LWS admission webhooks did not become ready in time." >&2
  exit 1
fi

# [START hypercomputer_tpu_infer_gemma4_26b_deploy]
envsubst '$RESERVATION_NAME $ZONE $VLLM_IMAGE' < gemma4-26b-multihost-v6e-2x4.yaml | kubectl apply -f -
# [END hypercomputer_tpu_infer_gemma4_26b_deploy]

echo "Deploying the model and tracking progress..."
# [START hypercomputer_tpu_infer_gemma4_26b_deploy_wait]
# Stream logs from the InitContainer to monitor model download
until kubectl get pod -l leaderworkerset.sigs.k8s.io/name=vllm-tpu-gemma4-26b -o jsonpath='{.items[*].status.initContainerStatuses[0].state}' 2>/dev/null | grep -qE "running|terminated"; do
  sleep 2
done
kubectl logs -f -l leaderworkerset.sigs.k8s.io/name=vllm-tpu-gemma4-26b -c prefetch-model --prefix

# When the pods transition to Running, monitor logs
kubectl wait --for=jsonpath='{.status.phase}'=Running --timeout=300s \
  pod -l leaderworkerset.sigs.k8s.io/name=vllm-tpu-gemma4-26b
kubectl logs -f -l leaderworkerset.sigs.k8s.io/name=vllm-tpu-gemma4-26b --prefix &
LOG_PID=$!
kubectl wait --for=condition=Ready --timeout=3600s pod -l role=leader
kill "${LOG_PID}" 2>/dev/null || true
# [END hypercomputer_tpu_infer_gemma4_26b_deploy_wait]
