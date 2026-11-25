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

: "${RESERVATION_NAME:?RESERVATION_NAME must be set (see 0_env.sh)}"
: "${VLLM_IMAGE:?VLLM_IMAGE must be set (see 0_env.sh)}"
: "${MODEL_ID:?MODEL_ID must be set (see 0_env.sh)}"

on_exit() {
  local status=$?
  if [ "${status}" -ne 0 ]; then
    echo "Deployment failed. Fetching diagnostic information..." >&2
    kubectl describe deployment/vllm-gemma4-31b || true
    kubectl describe pods -l app=vllm-gemma4-31b || true
    kubectl logs -l app=vllm-gemma4-31b --tail=200 || true
    kubectl logs -l app=vllm-gemma4-31b --previous --tail=200 || true
  fi
}
trap on_exit EXIT

# shellcheck disable=SC2016
# [START hypercomputer_gpu_infer_gemma4_31b_deploy]
envsubst '$RESERVATION_NAME $VLLM_IMAGE $MODEL_ID' < vllm-gemma-4-31b-it.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_gemma4_31b_deploy]

echo "Deploying the model and tracking progress..."
# [START hypercomputer_gpu_infer_gemma4_31b_deploy_wait]
kubectl wait \
    --for=condition=Available \
    --timeout=3600s deployment/vllm-gemma4-31b
# [END hypercomputer_gpu_infer_gemma4_31b_deploy_wait]
