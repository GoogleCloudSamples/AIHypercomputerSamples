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

echo "[$(date)] ==================== Creating a Google Cloud Storage bucket... ==================="
# [START hypercomputer_gpu_infer_deepseek32_bucket_create]
gcloud storage buckets create gs://"$GCS_BUCKET" --location="$REGION" --uniform-bucket-level-access
# [END hypercomputer_gpu_infer_deepseek32_bucket_create]

echo "[$(date)] ==================== Adding bucket permissions... ==================="
# [START hypercomputer_gpu_infer_deepseek32_add_bucket_permissions]
gcloud storage buckets add-iam-policy-binding gs://"$GCS_BUCKET" \
    --member="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/default/sa/default" \
    --role="roles/storage.objectAdmin"
# [END hypercomputer_gpu_infer_deepseek32_add_bucket_permissions]

echo "[$(date)] ==================== Submitting the model download job... ==================="
# [START hypercomputer_gpu_infer_deepseek32_download_job]
envsubst '$GCS_BUCKET' < deepseek-download-job.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek32_download_job]

echo "[$(date)] ==================== Waiting for the model download to complete... ==================="
# [START hypercomputer_gpu_infer_deepseek32_wait_job_completion]
kubectl wait \
    --for=condition=Complete \
    --timeout=7200s job/deepseek-download-job
# [END hypercomputer_gpu_infer_deepseek32_wait_job_completion]

echo "[$(date)] ==================== The model is downloaded. Deleting the job... ==================="
# [START hypercomputer_gpu_infer_deepseek32_delete_job]
kubectl delete job deepseek-download-job
# [END hypercomputer_gpu_infer_deepseek32_delete_job]
