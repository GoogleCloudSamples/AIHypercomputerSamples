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

# 1. Deploy Manifests
echo "[$(date)] ==================== Deploying manifests. ===================="
# [START hypercomputer_gpu_infer_llama4scout_deploy_manifests]
envsubst < manifests/vllm-l4-17b.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_llama4scout_deploy_manifests]
echo "[$(date)] ==================== Manifests deployed. ===================="


# 2. Wait for deployment ---
echo "[$(date)] ==================== Waiting for deployment. ===================="
# [START hypercomputer_gpu_infer_llama4scout_wait_for_deployment]
echo "Waiting for deployment to be ready (this may take up to 30 minutes)..."
kubectl wait \
    --for=condition=Available \
    --timeout=1800s \
    deployment/vllm-llama4-deployment
# [END hypercomputer_gpu_infer_llama4scout_wait_for_deployment]
echo "[$(date)] ==================== Deployment is available. ===================="
