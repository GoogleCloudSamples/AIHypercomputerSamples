#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file contains the exact documentation snippets for checking logs,
# containing placeholders like <pod suffix> that shouldn't be executed in CI.

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_cb_env]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export CLOUD_IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT/maxtext-images/maxtext_base:latest"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_cb_env]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_configure_blueprint]
# Example git diff output:
# diff --git a/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml b/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml
# index 4edeaaf1f..0f44b0ed2 100644
# --- a/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml
# +++ b/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml
# @@ -17,34 +17,34 @@ blueprint_name: gke-tpu-v6e
#  vars:
#    # The following variables should be over-written in the deployment.yaml file.
#    # Your GCP Project ID
# -  project_id:
# +  project_id: p3rf-sample-runner
#  
#    # This should be unique across all of your Cluster
#    # Toolkit Deployments.
#    deployment_name: gke-tpu-v6e
#  
#    # The GCP Region used for this deployment.
# -  region:
# +  region: us-east5
#  
#    # The GCP Zone used for this deployment.
# -  zone:
# +  zone: us-east5-b
#  
#    # The number of TPU slices to create
# -  num_slices:
# +  num_slices: 1
#  
#    # Machine type
#    machine_type: ct6e-standard-4t
#  
#    # The TPU placement topology for pod slice node pool.-  tpu_topology:
# +  tpu_topology: 4x8
#  
#    # Cidr block containing the IP of the machine calling terraform.
#    # To allow all (IAM restrictions still enforced), use 0.0.0.0/0
#    # To allow only your IP address, use <YOUR-IP-ADDRESS>/32
# -  authorized_cidr:
# +  authorized_cidr: 0.0.0.0/0
#  
#    # The name of the compute engine reservation of TPU v6e nodes
# -  reservation:
# +  reservation: reservation-20260528-194925
#  
#    system_node_pool_disk_size_gb: 200
#    v6e_node_pool_disk_size_gb: 100
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_configure_blueprint]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_model_logs]
# Check progress at
kubectl logs hf-to-mt-main-job-0-0-<pod suffix> -f
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_model_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_train_logs]
# Check progress at
kubectl logs sft-main-job-0-0-<pod suffix> -f
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_train_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_hf_logs]
# Check progress at
kubectl logs mt-to-hf-main-job-0-0-<pod suffix> -f

# The trained model is now available in gs://$GCS_BUCKET/qwen-3-14b/hf-trained/ - though again, it's ~2x the size of the original...
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_hf_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_cleanup_storage]
gcluster destroy ${CLUSTER_NAME} --auto-approve 
gcloud storage rm --recursive gs://$GCS_BUCKET
gcloud artifacts repositories delete ${REPOSITORY_NAME} --location=$REGION --project=$PROJECT --quiet
rm -f cloudbuild.yaml gke-tpu-v6e-advanced.yaml kueue-configuration.yaml.tftpl
rm -rf ${CLUSTER_NAME}
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_cleanup_storage]
