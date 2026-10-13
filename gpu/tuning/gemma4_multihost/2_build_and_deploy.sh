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

# 1. Build and Submit
# [START hypercomputer_gpu_tune_gemma4_multihost_gke_build_submit]
gcloud builds submit . \
    --substitutions=_ARTIFACT_REPO_LOCATION="${ARTIFACT_REPO_LOCATION}"
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_build_submit]
echo "[$(date)] ==================== Build finished. ===================="

# 2. Set image name for the job template
# [START hypercomputer_gpu_tune_gemma4_multihost_gke_set_image_url]
IMAGE_REGISTRY="${ARTIFACT_REPO_LOCATION}-docker.pkg.dev/${PROJECT_ID}"
export IMAGE_URL="${IMAGE_REGISTRY}/gemma/finetune-gemma-multihost-gpu:2.0.0"
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_set_image_url]

# 3. Deploy JobSet
# [START hypercomputer_gpu_tune_gemma4_multihost_gke_deploy_job]
envsubst '${RESERVATION} ${IMAGE_URL} ${NUM_NODES}' < finetune.yaml \
    | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_deploy_job]
echo "[$(date)] ==================== JobSet deployed. ===================="

# 4. Monitor JobSet and Verify Logs
declare -r JOB_NAME="finetune-jobset-workers-0"
echo "Waiting for JobSet to create Job ${JOB_NAME}..."
until kubectl get job "${JOB_NAME}" &>/dev/null; do
    echo "Job not found yet, retrying in 5 seconds..."
    sleep 5
done

echo "Waiting for Job ${JOB_NAME} to complete..."
kubectl wait --for=condition=complete "job/${JOB_NAME}" --timeout=14400s || {
    echo "Job failed or timed out. Fetching status and logs..."
    kubectl describe job "${JOB_NAME}"
    kubectl logs -l "job-name=${JOB_NAME}" --tail=200 || true
    exit 1
}

echo "[$(date)] ==================== JobSet completed. ===================="

