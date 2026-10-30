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

TPU_TYPE="${TPU_TYPE:-v7x}"

if [[ "${TPU_TYPE}" == "v6e" ]]; then
  DOWNLOAD_JOB="${DOWNLOAD_JOB:-download-qwen3}"
  SERVER_MANIFEST="${SERVER_MANIFEST:-v6e_qwen3_server_multihost_slice.yaml}"
  BENCHMARK_MANIFEST="${BENCHMARK_MANIFEST:-v6e_qwen3_benchmark_multihost_slice.yaml}"
else
  WORKLOAD_POLICY_NAME="${WORKLOAD_POLICY_NAME:-${CLUSTER_NAME}-policy}"
  DOWNLOAD_JOB="${DOWNLOAD_JOB:-download-qwen35}"
  SERVER_MANIFEST="${SERVER_MANIFEST:-v7x_qwen3_5_server_multihost_slice.yaml}"
  BENCHMARK_MANIFEST="${BENCHMARK_MANIFEST:-v7x_qwen3_5_benchmark_multihost_slice.yaml}"
fi

echo "[$(date)] ==================== Deleting Kubernetes workloads and secrets... ===================="
kubectl delete -f "${BENCHMARK_MANIFEST}" --ignore-not-found || true
kubectl delete job "${DOWNLOAD_JOB}" --ignore-not-found || true

if [[ "${TPU_TYPE}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_deploy_cleanup_v6e]
  kubectl delete -f v6e_qwen3_server_multihost_slice.yaml --ignore-not-found || true
  kubectl delete secret hf-secret --ignore-not-found || true
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_deploy_cleanup_v6e]
else
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_deploy_cleanup]
  kubectl delete -f v7x_qwen3_5_server_multihost_slice.yaml --ignore-not-found || true
  kubectl delete secret hf-secret --ignore-not-found || true
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_deploy_cleanup]
fi

echo "[$(date)] ==================== Deleting the GCS bucket... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_bucket_cleanup]
gcloud storage rm --recursive "gs://${GCS_BUCKET}" --project="${PROJECT_ID}" --quiet || true
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_bucket_cleanup]

echo "[$(date)] ==================== Deleting GKE TPU node pools, cluster, and workload policy... ===================="
if [[ "${TPU_TYPE}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_cleanup_v6e]
  for NODE_POOL_NAME in np-0 np-1; do
    gcloud container node-pools delete "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --location="${REGION}" \
        --project="${PROJECT_ID}" \
        --quiet || true
  done

  gcloud container clusters delete "${CLUSTER_NAME}" \
      --location="${REGION}" \
      --project="${PROJECT_ID}" \
      --quiet || true
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_cleanup_v6e]
else
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_cleanup]
  for NODE_POOL_NAME in np-0 np-1; do
    gcloud container node-pools delete "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --location="${REGION}" \
        --project="${PROJECT_ID}" \
        --quiet || true
  done

  gcloud container clusters delete "${CLUSTER_NAME}" \
      --location="${REGION}" \
      --project="${PROJECT_ID}" \
      --quiet || true

  gcloud compute resource-policies delete "${WORKLOAD_POLICY_NAME}" \
      --region="${REGION}" \
      --project="${PROJECT_ID}" \
      --quiet || true
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_cleanup]
fi

echo "[$(date)] ==================== Cleanup Complete. ===================="
