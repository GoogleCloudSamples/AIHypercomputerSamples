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

if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3-30B-A3B-FP8}"
  DOWNLOAD_MANIFEST="${DOWNLOAD_MANIFEST:-download_qwen3_30b.yaml}"
  DOWNLOAD_JOB="${DOWNLOAD_JOB:-download-qwen3}"
else
  MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3.5-397B-A17B-FP8}"
  DOWNLOAD_MANIFEST="${DOWNLOAD_MANIFEST:-download_model.yaml}"
  DOWNLOAD_JOB="${DOWNLOAD_JOB:-download-qwen35}"
fi

echo "[$(date)] ==================== Creating a Google Cloud Storage bucket gs://${GCS_BUCKET}... ===================="
if ! gcloud storage buckets describe "gs://${GCS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_bucket_create]
  gcloud storage buckets create "gs://${GCS_BUCKET}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_bucket_create]
else
  echo "Bucket gs://${GCS_BUCKET} already exists."
fi

echo "[$(date)] ==================== Adding bucket IAM permissions... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_add_bucket_permissions]
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")

gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/default/sa/default" \
    --role="roles/storage.admin"
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_add_bucket_permissions]

echo "[$(date)] ==================== Submitting the model download job (${DOWNLOAD_MANIFEST})... ===================="
if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_download_job_v6e]
  envsubst '$GCS_BUCKET' < download_qwen3_30b.yaml | kubectl apply -f -
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_download_job_v6e]
else
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_download_job]
  envsubst '$GCS_BUCKET' < download_model.yaml | kubectl apply -f -
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_download_job]
fi

echo "Waiting for the ${DOWNLOAD_JOB} pod to be created and start..."
pod_creation_timeout=300
elapsed=0
until [[ -n "$(kubectl get pods -l "job-name=${DOWNLOAD_JOB}" --no-headers 2>/dev/null)" ]]; do
  if [[ "${elapsed}" -ge "${pod_creation_timeout}" ]]; then
    echo "Error: Timed out after ${pod_creation_timeout}s waiting for ${DOWNLOAD_JOB} pod to be created." >&2
    kubectl describe job "${DOWNLOAD_JOB}" >&2 || true
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
if kubectl wait --for=condition=Ready pod -l "job-name=${DOWNLOAD_JOB}" --timeout=600s; then
  kubectl logs -f "job/${DOWNLOAD_JOB}" &
  LOG_PID=$!
  cleanup_logs() {
    kill "${LOG_PID}" 2>/dev/null || true
  }
  trap cleanup_logs EXIT
fi

if [[ -z "${DOWNLOAD_TIMEOUT:-}" || "${DOWNLOAD_TIMEOUT}" == "YOUR_DOWNLOAD_TIMEOUT" ]]; then
  DOWNLOAD_TIMEOUT="7200s"
fi

echo "[$(date)] ==================== Waiting for the model download to complete (up to ${DOWNLOAD_TIMEOUT})... ===================="
if ! kubectl wait \
    --for=condition=Complete \
    --timeout="${DOWNLOAD_TIMEOUT}" "job/${DOWNLOAD_JOB}"; then
  echo "Error: Model download job failed or timed out after ${DOWNLOAD_TIMEOUT}." >&2

  echo "================= [DIAGNOSTICS] Job Status =================" >&2
  kubectl get jobs "${DOWNLOAD_JOB}" -o yaml >&2 || true

  echo "================= [DIAGNOSTICS] Pod Status =================" >&2
  kubectl get pods -l "job-name=${DOWNLOAD_JOB}" -o wide >&2 || true
  POD_NAMES=$(kubectl get pods -l "job-name=${DOWNLOAD_JOB}" -o jsonpath='{.items[*].metadata.name}' || true)
  for pod in ${POD_NAMES}; do
    echo "============= [DIAGNOSTICS] Describe pod ${pod} =============" >&2
    kubectl describe pod "${pod}" >&2 || true
    echo "============= [DIAGNOSTICS] Logs for pod ${pod} (Tail 100) =============" >&2
    kubectl logs "${pod}" --tail=100 >&2 || true
    echo "============= [DIAGNOSTICS] Previous Container Logs for pod ${pod} =============" >&2
    kubectl logs "${pod}" --previous --tail=100 2>/dev/null >&2 || true
  done
  exit 1
fi

echo "Verifying uploaded model shards in ${GCS_BUCKET} bucket..."
SHARD_COUNT=$(gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/*.safetensors" | wc -l)
echo "Found ${SHARD_COUNT} safetensors shards in gs://${GCS_BUCKET}/${MODEL_NAME}/."

if [[ "${TPU_TYPE:-v7x}" == "v6e" ]]; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_delete_download_job_v6e]
  kubectl delete job download-qwen3
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_delete_download_job_v6e]
else
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_delete_download_job]
  kubectl delete job download-qwen35
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_delete_download_job]
fi
echo "[$(date)] ==================== Model download to GCS completed successfully! ===================="
