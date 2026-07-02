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

# [START hypercomputer_gpu_tune_gemma3_slurm_toolkit_download]
# Find all available releases at: https://github.com/GoogleCloudPlatform/cluster-toolkit/releases
# Set the desired version TAG (e.g., v1.96.0)
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
# [END hypercomputer_gpu_tune_gemma3_slurm_toolkit_prepare_vars]

# [START hypercomputer_gpu_tune_gemma3_slurm_install_toolkit]
# Download and extract the platform-specific bundle
curl -LO "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_TAG}/gcluster_bundle_${OS}_${ARCH}.zip"
unzip "gcluster_bundle_${OS}_${ARCH}.zip" -d cluster-toolkit/
rm -f "gcluster_bundle_${OS}_${ARCH}.zip"
# [END hypercomputer_gpu_tune_gemma3_slurm_install_toolkit]

# [START hypercomputer_gpu_tune_gemma3_slurm_toolkit_setpath]
export PATH="$(pwd)/cluster-toolkit:${PATH}"
gcluster --version
# [END hypercomputer_gpu_tune_gemma3_slurm_toolkit_setpath]


# ==============================================================================
# Create an A4 Slurm Cluster
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma3_slurm_change_dir]
cd examples/machine-learning/a4-highgpu-8g/
# [END hypercomputer_gpu_tune_gemma3_slurm_change_dir]

# [START hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster_skip]
gcluster deploy "${CLUSTER_NAME}" --auto-approve --skip "image" -w
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
