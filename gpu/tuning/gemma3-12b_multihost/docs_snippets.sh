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
# [START hypercomputer_gpu_tune_gemma3_multihost_gke_setup_manifest_dir]
mkdir llm-finetuning-gemma
cd llm-finetuning-gemma
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_setup_manifest_dir]

# [START hypercomputer_gpu_tune_gemma3_multihost_gke_monitor_pods]
watch kubectl get pods
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_monitor_pods]

# [START hypercomputer_gpu_tune_gemma3_multihost_gke_monitor_logs]
kubectl logs -l "job-name=finetune-jobset-workers-0" -f
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_monitor_logs]

# [START hypercomputer_gpu_tune_gemma3_multihost_gke_view_metrics]
echo "https://console.cloud.google.com/kubernetes/clusters/details/${CLUSTER_REGION}/${CLUSTER_NAME}/observability?mods=monitoring_api_prod&project=${PROJECT_ID}&pageState=("timeRange":("duration":"PT1H"),"nav":("section":"gpu"),"groupBy":("groupByType":"namespacesTop5"))"
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_view_metrics]

# [START hypercomputer_gpu_tune_gemma3_multihost_gke_delete_job]
kubectl delete jobset finetune-jobset
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_delete_job]

# [START hypercomputer_gpu_tune_gemma3_multihost_gke_delete_cluster]
gcloud container clusters delete "${CLUSTER_NAME}" \
    --region="${CLUSTER_REGION}"
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_delete_cluster]

# [START hypercomputer_gpu_tune_gemma3_multihost_gke_delete_repo]
gcloud artifacts repositories delete gemma \
    --location="${ARTIFACT_REPO_LOCATION}" \
    --quiet
# [END hypercomputer_gpu_tune_gemma3_multihost_gke_delete_repo]
