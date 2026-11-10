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
# [START hypercomputer_gpu_infer_deepseek31_bucket_create]
gcloud storage buckets create gs://$GCS_BUCKET --location=$REGION --uniform-bucket-level-access
# [END hypercomputer_gpu_infer_deepseek31_bucket_create]

echo "[$(date)] ==================== Adding bucket permissions... ==================="
# [START hypercomputer_gpu_infer_deepseek31_add_bucket_permissions]
gcloud storage buckets add-iam-policy-binding gs://$GCS_BUCKET \
    --member="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/default/sa/default" \
    --role="roles/storage.objectAdmin"
# [END hypercomputer_gpu_infer_deepseek31_add_bucket_permissions]

echo "[$(date)] ==================== Submitting the model download job... ==================="
# [START hypercomputer_gpu_infer_deepseek31_download_job]
envsubst '$GCS_BUCKET' < deepseek-download-job.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek31_download_job]

echo "[$(date)] ==================== Waiting for the model download to complete... ==================="
download_job="job/deepseek-download-job"
seconds=0
deadline=7200

job_condition() {
  kubectl get "$download_job" -o jsonpath="{.status.conditions[?(@.type==\"$1\")].status}"
}
pod_restarts() {
  kubectl get pods -l job-name=deepseek-download-job \
    -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || true
}
until [[ "$(job_condition Complete)" == "True" ]]; do
  restart_count="$(pod_restarts)"
  if [[ "$(job_condition Failed)" == "True" ]] || (( ${restart_count:-0} >= 2 )) || (( seconds >= deadline )); then
    echo "ERROR: $download_job failed (restarts=${restart_count:-0}) or did not complete within 7200s."
    kubectl describe "$download_job" || true
    kubectl describe pod -l job-name=deepseek-download-job || true
    kubectl logs "$download_job" --all-containers --tail=200 || true
    kubectl logs "$download_job" --all-containers --previous --tail=200 2>/dev/null || true
    exit 1
  fi
  sleep 10
  seconds=$((seconds + 10))
done

echo "[$(date)] ==================== The model is downloaded. Deleting the job... ==================="
# [START hypercomputer_gpu_infer_deepseek31_delete_job]
kubectl delete job deepseek-download-job
# [END hypercomputer_gpu_infer_deepseek31_delete_job]
