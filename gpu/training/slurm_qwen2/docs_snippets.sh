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

# [START hypercomputer_gpu_train_qwen2_slurm_download_toolkit]
export CLUSTER_TOOLKIT_TAG=v1.96.0

# Detect OS (linux or mac)
case "$(uname -s)" in
  Linux*)     OS="linux" ;;
  Darwin*)    OS="mac" ;;
  *)          echo "Error: Unsupported operating system: $(uname -s)" >&2; exit 1 ;;
esac

# Detect Architecture (amd64 or arm64)
case "$(uname -m)" in
  x86_64)     ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)          echo "Error: Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
# [END hypercomputer_gpu_train_qwen2_slurm_download_toolkit]

# [START hypercomputer_gpu_train_qwen2_slurm_instal_toolkit]
# Download and extract the platform-specific bundle
curl -LO "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_TAG}/gcluster_bundle_${OS}_${ARCH}.zip"
unzip "gcluster_bundle_${OS}_${ARCH}.zip" -d cluster-toolkit/
rm -f "gcluster_bundle_${OS}_${ARCH}.zip"
# [END hypercomputer_gpu_train_qwen2_slurm_instal_toolkit]

# [START hypercomputer_gpu_train_qwen2_slurm_path]
export CLUSTER_TOOLKIT_PATH="$(pwd)/cluster-toolkit"
export PATH="${CLUSTER_TOOLKIT_PATH}:${PATH}"
gcluster --version
# [END hypercomputer_gpu_train_qwen2_slurm_path]

# ==============================================================================
# Create an A4 Slurm Cluster
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_deploy_cluster_create]
gcluster deploy "${CLUSTER_NAME}" --auto-approve --skip "image" -w
# [END hypercomputer_gpu_train_qwen2_slurm_deploy_cluster_create]

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
    -- -t "export HF_TOKEN='${HF_TOKEN}'; bash -l"
# [END hypercomputer_gpu_train_qwen2_slurm_ssh_login]

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
tail -f ~/logs/slurm-1.out # (or .err, depending on where the script is currently sending logs)
# [END hypercomputer_gpu_train_qwen2_slurm_monitor_logs]

# ==============================================================================
# Monitor Workload
# ==============================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_monitor_workload_terminal]
open "https://console.cloud.google.com/monitoring/metrics-explorer?project=${PROJECT_ID}&pageState=%7B%22xyChart%22%3A%7B%22dataSets%22%3A%5B%7B%22timeSeriesFilter%22%3A%7B%22filter%22%3A%22metric.type%3D%5C%22agent.googleapis.com%2Fgpu%2Futilization%5C%22%20resource.type%3D%5C%22gce_instance%5C%22%22%2C%22perSeriesAligner%22%3A%22ALIGN_MEAN%22%7D%2C%22plotType%22%3A%22LINE%22%7D%5D%7D%7D"
# [END hypercomputer_gpu_train_qwen2_slurm_monitor_workload_terminal]

# [START hypercomputer_gpu_train_qwen2_slurm_monitor_workload_browser]
https://console.cloud.google.com/monitoring/metrics-explorer?project=PROJECT_ID&pageState=%7B%22xyChart%22%3A%7B%22dataSets%22%3A%5B%7B%22timeSeriesFilter%22%3A%7B%22filter%22%3A%22metric.type%3D%5C%22agent.googleapis.com%2Fgpu%2Futilization%5C%22%20resource.type%3D%5C%22gce_instance%5C%22%22%2C%22perSeriesAligner%22%3A%22ALIGN_MEAN%22%7D%2C%22plotType%22%3A%22LINE%22%7D%5D%7D%7D
# [END hypercomputer_gpu_train_qwen2_slurm_monitor_workload_browser]

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

# [START hypercomputer_gpu_train_qwen2_slurm_destroy_image]
http://console.cloud.google.com/compute/images
# [END hypercomputer_gpu_train_qwen2_slurm_destroy_image]
