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
# Prepare Environment
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_clone_toolkit]
git clone https://github.com/GoogleCloudPlatform/cluster-toolkit.git
# [END hypercomputer_gpu_train_qwen2_slurm_clone_toolkit]

# ==============================================================================
# Create an A4 Slurm Cluster
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_cd_toolkit]
cd cluster-toolkit
# [END hypercomputer_gpu_train_qwen2_slurm_cd_toolkit]

# [START hypercomputer_gpu_train_qwen2_slurm_build_gcluster]
make
# [END hypercomputer_gpu_train_qwen2_slurm_build_gcluster]

# [START hypercomputer_gpu_train_qwen2_slurm_cd_directory]
cd examples/machine-learning/a4-highgpu-8g/
# [START hypercomputer_gpu_train_qwen2_slurm_cd_directory]

# [START hypercomputer_gpu_train_qwen2_slurm_deploy_cluster_skip]
gcluster deploy "${CLUSTER_NAME}" --auto-approve --skip "image" -w ???
# [END hypercomputer_gpu_train_qwen2_slurm_deploy_cluster_skip]

# ==============================================================================
# Prepare Workload
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_list_vms]
gcloud compute instances list --filter="machineType:a4-highgpu-8g"
# [END hypercomputer_gpu_train_qwen2_slurm_list_vms]

# [START hypercomputer_gpu_train_qwen2_slurm_scp_script]
gcloud compute scp \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  ./install_environment.sh \
  ./requirements.txt \
  ./submit.slurm \
  ./accelerate_config.yaml \
  ./train.py \
  ./preprocess_data.py \
  "${LOGIN_NODE}":~/
# [END hypercomputer_gpu_train_qwen2_slurm_scp_script]

# [START hypercomputer_gpu_train_qwen2_slurm_ssh_login]
gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --tunnel-through-iap \
    --zone="${ZONE}"
# [END hypercomputer_gpu_train_qwen2_slurm_ssh_login]

# [START hypercomputer_gpu_train_qwen2_slurm_hf_token]
export HF_TOKEN="HUGGING_FACE_TOKEN"
# [END hypercomputer_gpu_train_qwen2_slurm_hf_token]

# [START hypercomputer_gpu_train_qwen2_slurm_install_environment]
chmod +x install_environment.sh
./install_environment.sh
# [END hypercomputer_gpu_train_qwen2_slurm_install_environment]

# ==============================================================================
# Start Pre - Training
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_sbatch]
sbatch submit.slurm
# [END hypercomputer_gpu_train_qwen2_slurm_sbatch]

# [START hypercomputer_gpu_train_qwen2_slurm_monitor_logs]
tail -f ~/logs/slurm-1.out
# [END hypercomputer_gpu_train_qwen2_slurm_monitor_logs]

# ==============================================================================
# Monitor Workload
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_monitor_workload_terminal]
open "https://console.cloud.google.com/monitoring/metrics-explorer?project=${PROJECT_ID}&pageState=%7B%22xyChart%22%3A%7B%22dataSets%22%3A%5B%7B%22timeSeriesFilter%22%3A%7B%22filter%22%3A%22metric.type%3D%5C%22agent.googleapis.com%2Fgpu%2Futilization%5C%22%20resource.type%3D%5C%22gce_instance%5C%22%22%2C%22perSeriesAligner%22%3A%22ALIGN_MEAN%22%7D%2C%22plotType%22%3A%22LINE%22%7D%5D%7D%7D"
# [END hypercomputer_gpu_train_qwen2_slurm_monitor_workload_terminal]

# [START hypercomputer_gpu_train_qwen2_slurm_monitor_workload_browser]
https://console.cloud.google.com/monitoring/metrics-explorer?project=YOUR_PROJECT_ID&pageState=%7B%22xyChart%22%3A%7B%22dataSets%22%3A%5B%7B%22timeSeriesFilter%22%3A%7B%22filter%22%3A%22metric.type%3D%5C%22agent.googleapis.com%2Fgpu%2Futilization%5C%22%20resource.type%3D%5C%22gce_instance%5C%22%22%2C%22perSeriesAligner%22%3A%22ALIGN_MEAN%22%7D%2C%22plotType%22%3A%22LINE%22%7D%5D%7D%7D
# [START hypercomputer_gpu_train_qwen2_slurm_monitor_workload_browser]

# ==============================================================================
# Download Model
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_download_model]
# From your local machine
LOGIN_NODE="your-login-node-name" # e.g., a4high-login-001
PROJECT_ID="your-gcp-project-id"
ZONE="your-cluster-zone" # e.g., us-west4-a

gcloud compute scp --project="${PROJECT_ID}" --zone="${ZONE}" --tunnel-through-iap \
  "${LOGIN_NODE}":~/qwen2-from-scratch-on-smollm-fineweb/ ./qwen2-trained-model/ --recurse
# [END hypercomputer_gpu_train_qwen2_slurm_download_model]

# ==============================================================================
# Cleanup
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_destroy_cluster]
./gcluster destroy a4-high --auto-approve
# [END hypercomputer_gpu_train_qwen2_slurm_destroy_cluster]
