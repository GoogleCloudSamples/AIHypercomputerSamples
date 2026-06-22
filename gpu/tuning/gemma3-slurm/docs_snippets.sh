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

# ==============================================================================
# Prerequisites
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_enable_sa]
gcloud iam service-accounts enable PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --project=PROJECT_ID
# [END hypercomputer_gpu_tune_gemma3_slurm_enable_sa]

# [START hypercomputer_gpu_tune_gemma3_slurm_add_iam]
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role=roles/editor
# [END hypercomputer_gpu_tune_gemma3_slurm_add_iam]

# [START hypercomputer_gpu_tune_gemma3_slurm_adc]
gcloud auth application-default login
# [END hypercomputer_gpu_tune_gemma3_slurm_adc]

# [START hypercomputer_gpu_tune_gemma3_slurm_oslogin]
gcloud compute project-info add-metadata --metadata=enable-oslogin=TRUE
# [END hypercomputer_gpu_tune_gemma3_slurm_oslogin]

# ==============================================================================
# Prepare Environment
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_clone_toolkit]
git clone https://github.com/GoogleCloudPlatform/cluster-toolkit.git
# [END hypercomputer_gpu_tune_gemma3_slurm_clone_toolkit]

# [START hypercomputer_gpu_tune_gemma3_slurm_create_bucket]
gcloud storage buckets create gs://BUCKET_NAME \
    --project=PROJECT_ID
# [END hypercomputer_gpu_tune_gemma3_slurm_create_bucket]

# ==============================================================================
# Create an A4 Slurm Cluster
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_build_gcluster]
cd cluster-toolkit
make
# [END hypercomputer_gpu_tune_gemma3_slurm_build_gcluster]

# [START hypercomputer_gpu_tune_gemma3_slurm_deploy_yaml]
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: BUCKET_NAME

vars:
  deployment_name: a4-high
  project_id: PROJECT_ID
  region: REGION
  zone: ZONE
  a4h_cluster_size: 2
  a4h_reservation_name: RESERVATION_URL
# [END hypercomputer_gpu_tune_gemma3_slurm_deploy_yaml]

# [START hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster]
./gcluster deploy -d examples/machine-learning/a4-highgpu-8g/a4high-slurm-deployment.yaml examples/machine-learning/a4-highgpu-8g/a4high-slurm-blueprint.yaml --auto-approve
# [END hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster]

# [START hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster_skip]
./gcluster deploy -d examples/machine-learning/a4-highgpu-8g/a4high-slurm-deployment.yaml examples/machine-learning/a4-highgpu-8g/a4high-slurm-blueprint.yaml --auto-approve --skip "image" -w
# [END hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster_skip]

# ==============================================================================
# Prepare Workload
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_list_vms]
gcloud compute instances list --filter="machineType:a4-highgpu-8g"
# [END hypercomputer_gpu_tune_gemma3_slurm_list_vms]

# [START hypercomputer_gpu_tune_gemma3_slurm_scp_scripts]
gcloud compute scp \
  --project="PROJECT_ID" \
  --zone="ZONE" \
  --tunnel-through-iap \
  ./train.py \
  ./requirements.txt \
  ./submit.slurm \
  ./install_environment.sh \
  ./accelerate_config.yaml \
  "LOGIN_NODE_NAME":~/
# [END hypercomputer_gpu_tune_gemma3_slurm_scp_scripts]

# [START hypercomputer_gpu_tune_gemma3_slurm_ssh_login]
gcloud compute ssh LOGIN_NODE_NAME \
    --project="PROJECT_ID" \
    --tunnel-through-iap \
    --zone="ZONE"
# [END hypercomputer_gpu_tune_gemma3_slurm_ssh_login]

# [START hypercomputer_gpu_tune_gemma3_slurm_hf_token]
export HUGGING_FACE_TOKEN="HUGGING_FACE_TOKEN"
# [END hypercomputer_gpu_tune_gemma3_slurm_hf_token]

# [START hypercomputer_gpu_tune_gemma3_slurm_install_tools]
chmod +x install_environment.sh
./install_environment.sh
# [END hypercomputer_gpu_tune_gemma3_slurm_install_tools]

# ==============================================================================
# Start Fine-Tuning
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_sbatch]
sbatch submit.slurm
# [END hypercomputer_gpu_tune_gemma3_slurm_sbatch]

# [START hypercomputer_gpu_tune_gemma3_slurm_monitor_tail]
tail -f slurm-gemma3-finetune.err
# [END hypercomputer_gpu_tune_gemma3_slurm_monitor_tail]

# ==============================================================================
# Cleanup
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_destroy_cluster]
./gcluster destroy a4-high --auto-approve
# [END hypercomputer_gpu_tune_gemma3_slurm_destroy_cluster]
