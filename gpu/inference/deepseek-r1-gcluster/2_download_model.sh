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

JOB_NAME="download-deepseek-r1"
EXPECTED_SHARDS=163

echo "Creating the Cloud Storage bucket for the model weights..."
if gcloud storage buckets describe "gs://${MODEL_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Bucket gs://${MODEL_BUCKET} already exists. Skipping creation."
else
# [START hypercomputer_gpu_infer_deepseek_r1_model_bucket_create]
gcloud storage buckets create "gs://${MODEL_BUCKET}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
# [END hypercomputer_gpu_infer_deepseek_r1_model_bucket_create]
fi

echo "Granting bucket permissions..."
# [START hypercomputer_gpu_infer_deepseek_r1_model_bucket_iam]
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")

gcloud storage buckets add-iam-policy-binding "gs://${MODEL_BUCKET}" \
    --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/default/sa/default" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets add-iam-policy-binding "gs://${MODEL_BUCKET}" \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets add-iam-policy-binding "gs://${MODEL_BUCKET}" \
    --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

# legacyBucketReader is required to load the model with --load-format runai_streamer
gcloud storage buckets add-iam-policy-binding "gs://${MODEL_BUCKET}" \
    --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.legacyBucketReader"
# [END hypercomputer_gpu_infer_deepseek_r1_model_bucket_iam]

# [START hypercomputer_gpu_infer_deepseek_r1_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek_r1_secret_create]

# Jobs are immutable, so remove any leftover job from a previous run.
kubectl delete job "${JOB_NAME}" --ignore-not-found

echo "Starting the model download job..."
# [START hypercomputer_gpu_infer_deepseek_r1_download_job]
envsubst '$MODEL_BUCKET' < download_model.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek_r1_download_job]

LIMIT=60
count=0
until kubectl get pod -l job-name="${JOB_NAME}" -o name | grep -q "pod/"; do
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for the download pod to be created." >&2
    exit 1
  fi
  echo "Waiting for the download pod to be created..."
  sleep 5
  count=$((count + 1))
done

if ! kubectl wait --for=condition=Ready --timeout=600s pod -l job-name="${JOB_NAME}"; then
  echo "Download pod failed to start within 10 minutes! Here are the events:" >&2
  kubectl describe pod -l job-name="${JOB_NAME}"
  exit 1
fi

echo "Download pod is running. Streaming logs while the model downloads (~30-40 minutes)..."
kubectl logs -f "job/${JOB_NAME}" &
LOG_PID=$!
trap 'kill "${LOG_PID}" 2>/dev/null || true' EXIT

# Wait up to 90 minutes for the job to complete or fail.
LIMIT=540
count=0
while true; do
  CONDITIONS=$(kubectl get job "${JOB_NAME}" -o jsonpath='{.status.conditions[?(@.status=="True")].type}' 2>/dev/null || true)
  if [[ "${CONDITIONS}" == *Complete* ]]; then
    break
  fi
  if [[ "${CONDITIONS}" == *Failed* ]]; then
    echo "Error: model download job failed." >&2
    kubectl describe job "${JOB_NAME}"
    exit 1
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for the model download job to complete." >&2
    exit 1
  fi
  sleep 10
  count=$((count + 1))
done
echo "Model download job completed."

SHARDS=$( (gcloud storage ls "gs://${MODEL_BUCKET}/DeepSeek-R1/*.safetensors" 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "${SHARDS}" -ne "${EXPECTED_SHARDS}" ]; then
  echo "Error: found ${SHARDS}/${EXPECTED_SHARDS} safetensors shards in gs://${MODEL_BUCKET}/DeepSeek-R1." >&2
  exit 1
fi
echo "All ${SHARDS} safetensors shards are in gs://${MODEL_BUCKET}/DeepSeek-R1."

# [START hypercomputer_gpu_infer_deepseek_r1_download_job_delete]
kubectl delete job download-deepseek-r1
# [END hypercomputer_gpu_infer_deepseek_r1_download_job_delete]
