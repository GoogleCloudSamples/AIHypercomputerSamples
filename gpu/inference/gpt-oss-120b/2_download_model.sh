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
# [START hypercomputer_gpu_infer_gptoss120b_bucket_create]
gcloud storage buckets create gs://$GCS_BUCKET --location=$REGION --uniform-bucket-level-access
# [END hypercomputer_gpu_infer_gptoss120b_bucket_create]

echo "[$(date)] ==================== Adding bucket permissions... ==================="
# [START hypercomputer_gpu_infer_gptoss120b_add_bucket_permissions]
gcloud storage buckets add-iam-policy-binding gs://$GCS_BUCKET \
    --member="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/default/sa/default" \
    --role="roles/storage.objectAdmin"
# [END hypercomputer_gpu_infer_gptoss120b_add_bucket_permissions]

echo "[$(date)] ==================== Submitting the model download job... ==================="
# [START hypercomputer_gpu_infer_gptoss120b_download_job]
envsubst '$GCS_BUCKET' < gpt-download-job.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_gptoss120b_download_job]

if [[ -z "${DOWNLOAD_TIMEOUT}" || "${DOWNLOAD_TIMEOUT}" == "YOUR_DOWNLOAD_TIMEOUT" ]]; then
  DOWNLOAD_TIMEOUT="7200s"
fi

echo "[$(date)] ==================== Waiting for the model download to complete (up to ${DOWNLOAD_TIMEOUT})... ==================="
if ! kubectl wait \
    --for=condition=Complete \
    --timeout="${DOWNLOAD_TIMEOUT}" job/gpt-download-job; then
    echo "Error: Model download job failed or timed out after ${DOWNLOAD_TIMEOUT}."
    
    echo "================= [DIAGNOSTICS] Job Status ================="
    kubectl get jobs gpt-download-job -o yaml || true

    echo "================= [DIAGNOSTICS] Job Logs ================="
    kubectl logs -l job-name=gpt-download-job --tail=50 || true

    echo "================= [DIAGNOSTICS] Pod Status ================="
    kubectl get pods -l job-name=gpt-download-job -o wide || true
    POD_NAMES=$(kubectl get pods -l job-name=gpt-download-job -o jsonpath='{.items[*].metadata.name}' || true)
    for pod in $POD_NAMES; do
        echo "============= [DIAGNOSTICS] Describe pod $pod ============="
        kubectl describe pod "$pod" || true
        echo "============= [DIAGNOSTICS] Logs for pod $pod (Tail 100) ============="
        kubectl logs "$pod" --tail=100 || true
        echo "[DIAGNOSTICS] Previous Container Logs for pod $pod (if restarted) ============="
        kubectl logs "$pod" --previous --tail=100 2>/dev/null || true
    done
    exit 1
fi
echo "Job gpt-download-job finished successfully."

echo "[$(date)] ==================== Deleting the model download job... ==================="
# [START hypercomputer_gpu_infer_gptoss120b_delete_job]
kubectl delete job gpt-download-job
# [END hypercomputer_gpu_infer_gptoss120b_delete_job]
