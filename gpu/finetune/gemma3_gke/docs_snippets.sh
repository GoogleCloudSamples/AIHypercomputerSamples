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
# [START hypercomputer_gpu_tune_gemma3_gke_setup_manifest_dir]
mkdir llm-finetuning-gemma
cd llm-finetuning-gemma
# [END hypercomputer_gpu_tune_gemma3_gke_setup_manifest_dir]

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
