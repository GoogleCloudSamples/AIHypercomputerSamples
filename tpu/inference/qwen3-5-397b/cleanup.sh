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

echo "[$(date)] ==================== Deleting Kubernetes workloads and secrets... ===================="
if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  kubectl delete -f qwen3-benchmark-8k1k.yaml --ignore-not-found || true

  # [START hypercomputer_tpu_infer_qwen3_5_397b_deploy_cleanup_v6]
  kubectl delete -f qwen3_server.yaml --ignore-not-found || true
  kubectl delete secret hf-secret --ignore-not-found || true
  # [END hypercomputer_tpu_infer_qwen3_5_397b_deploy_cleanup_v6]
else
  kubectl delete -f qwen3_5-benchmark-8k1k.yaml --ignore-not-found || true

  # [START hypercomputer_tpu_infer_qwen3_5_397b_deploy_cleanup]
  kubectl delete -f qwen3_5_server.yaml --ignore-not-found || true
  kubectl delete secret hf-secret --ignore-not-found || true
  # [END hypercomputer_tpu_infer_qwen3_5_397b_deploy_cleanup]
fi

echo "[$(date)] ==================== Deleting GKE TPU node pool and cluster... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_cluster_cleanup]
gcloud container node-pools delete "${NODE_POOL_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet || true

gcloud container clusters delete "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet || true
# [END hypercomputer_tpu_infer_qwen3_5_397b_cluster_cleanup]
