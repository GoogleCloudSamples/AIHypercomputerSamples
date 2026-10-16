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
kubectl delete -f v6e_qwen3_benchmark_multi.yaml --ignore-not-found || true
kubectl delete job download-qwen3 --ignore-not-found || true

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_deploy_cleanup]
kubectl delete -f v6e_qwen3_server_multi.yaml --ignore-not-found || true
kubectl delete secret hf-secret --ignore-not-found || true
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_deploy_cleanup]

echo "[$(date)] ==================== Deleting the GCS bucket... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_bucket_cleanup]
gcloud storage rm --recursive "gs://${GCS_BUCKET}" --project="${PROJECT_ID}" --quiet || true
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_bucket_cleanup]

echo "[$(date)] ==================== Deleting GKE TPU node pools and cluster... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_cluster_cleanup]
gcloud container node-pools delete "${NODE_POOL_NAME_0}" \
    --cluster="${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet || true

gcloud container node-pools delete "${NODE_POOL_NAME_1}" \
    --cluster="${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet || true

gcloud container clusters delete "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet || true
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_cluster_cleanup]

echo "[$(date)] ==================== Cleanup Complete. ===================="
