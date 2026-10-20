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

if [[ "${USE_GCSFUSE:-false}" != "true" ]]; then
  echo "[$(date)] USE_GCSFUSE is false (Option A: model weights will be downloaded from Hugging Face to local SSD on each node during 3_deploy_model.sh)."
  exit 0
fi

STAGE_MANIFEST="qwen3.8-2.4t-nvfp4-stage-weights-job.yaml"
if [[ ! -f "${STAGE_MANIFEST}" ]]; then
  echo "Error: Stage weights manifest '${STAGE_MANIFEST}' not found in $(pwd)." >&2
  exit 1
fi

if [[ -z "${WEIGHTS_BUCKET:-}" || "${WEIGHTS_BUCKET}" == "YOUR_WEIGHTS_BUCKET_NAME" ]]; then
  WEIGHTS_BUCKET="${GCS_BUCKET}-weights"
fi

echo "[$(date)] ==================== Creating GCS bucket gs://${WEIGHTS_BUCKET} for model weights... ===================="
if ! gcloud storage buckets describe "gs://${WEIGHTS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  # [START hypercomputer_gpu_infer_qwen38_2t_create_weights_bucket]
  gcloud storage buckets create "gs://${WEIGHTS_BUCKET}" \
      --default-storage-class=STANDARD \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access

  GSA=$(kubectl get sa workload-identity-k8s-sa -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}')
  gcloud storage buckets add-iam-policy-binding "gs://${WEIGHTS_BUCKET}" \
      --member="serviceAccount:${GSA}" \
      --role="roles/storage.objectUser"
  # [END hypercomputer_gpu_infer_qwen38_2t_create_weights_bucket]
else
  echo "Bucket gs://${WEIGHTS_BUCKET} already exists."
fi

echo "[$(date)] ==================== Submitting weight staging job... ===================="
# [START hypercomputer_gpu_infer_qwen38_2t_stage_weights]
sed "s/<BUCKET_NAME>/${WEIGHTS_BUCKET}/g" qwen3.8-2.4t-nvfp4-stage-weights-job.yaml | kubectl apply -f -

kubectl wait --for=condition=complete job/qwen3-8-2-4t-stage-weights --timeout=2h

kubectl delete job qwen3-8-2-4t-stage-weights
# [END hypercomputer_gpu_infer_qwen38_2t_stage_weights]

echo "[$(date)] ==================== Model weights staged to gs://${WEIGHTS_BUCKET}! ===================="
