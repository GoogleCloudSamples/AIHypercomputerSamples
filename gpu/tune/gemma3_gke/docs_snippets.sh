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
#
#
# [START hypercomputer_gpu_tune_gemma3_gke_iam]
declare -a ROLES=(
  "roles/compute.admin"
  "roles/storage.admin"
  "roles/iam.serviceAccountUser"
  "roles/artifactregistry.admin"
  "roles/cloudbuild.builds.editor"
  "roles/serviceusage.serviceUsageAdmin"
)

for i in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="user:${USER_EMAIL}" \
    --role="$i"
done
# [END hypercomputer_gpu_tune_gemma3_gke_iam]

# [START hypercomputer_gpu_tune_gemma3_gke_create_cluster]
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --release-channel=rapid
# [END hypercomputer_gpu_tune_gemma3_gke_create_cluster]

# [START hypercomputer_gpu_tune_gemma3_gke_get_credentials]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}"
# [END hypercomputer_gpu_tune_gemma3_gke_get_credentials]

# [START hypercomputer_gpu_tune_gemma3_gke_create_secret]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_create_secret]

# [START hypercomputer_gpu_tune_gemma3_gke_create_repo]
gcloud artifacts repositories create gemma \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Repository for Gemma fine tuning workload containers"
# [END hypercomputer_gpu_tune_gemma3_gke_create_repo]

# [START hypercomputer_gpu_tune_gemma3_gke_build_submit]
gcloud builds submit .
# [END hypercomputer_gpu_tune_gemma3_gke_build_submit]

# [START hypercomputer_gpu_tune_gemma3_gke_deploy_job]
envsubst < finetune.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_deploy_job]

# [START hypercomputer_gpu_tune_gemma3_gke_monitor_pods]
kubectl get pods
# [END hypercomputer_gpu_tune_gemma3_gke_monitor_pods]

# [START hypercomputer_gpu_tune_gemma3_gke_monitor_logs]
# kubectl logs job.batch/finetune-job -f
# [END hypercomputer_gpu_tune_gemma3_gke_monitor_logs]

# [START hypercomputer_gpu_tune_gemma3_gke_delete_job]
kubectl delete job finetune-job
# [END hypercomputer_gpu_tune_gemma3_gke_delete_job]

# [START hypercomputer_gpu_tune_gemma3_gke_delete_cluster]
gcloud container clusters delete "${CLUSTER_NAME}" \
    --region="${REGION}"
# [END hypercomputer_gpu_tune_gemma3_gke_delete_cluster]