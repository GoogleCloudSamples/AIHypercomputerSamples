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

# [START hypercomputer_gpu_tune_mixtral_slurm_download_toolkit]
export CLUSTER_TOOLKIT_TAG=v1.97.0

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
# [END hypercomputer_gpu_tune_mixtral_slurm_download_toolkit]

# [START hypercomputer_gpu_tune_mixtral_slurm_instal_toolkit]
# Download and extract the platform-specific bundle
curl -LO "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_TAG}/gcluster_bundle_${OS}_${ARCH}.zip"
unzip "gcluster_bundle_${OS}_${ARCH}.zip" -d cluster-toolkit/
rm -f "gcluster_bundle_${OS}_${ARCH}.zip"
# [END hypercomputer_gpu_tune_mixtral_slurm_instal_toolkit]

# [START hypercomputer_gpu_tune_mixtral_slurm_path]
export CLUSTER_TOOLKIT_PATH="$(pwd)/cluster-toolkit"
export PATH="${CLUSTER_TOOLKIT_PATH}:${PATH}"
gcluster --version
# [END hypercomputer_gpu_tune_mixtral_slurm_path]

# ==============================================================================
# Prepare Workload
# ==============================================================================

# [START hypercomputer_gpu_tune_mixtral_slurm_firewall_rule]
gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
  --project="${PROJECT_ID}" \
  --network="${CLUSTER_NETWORK}" \
  --direction=INGRESS \
  --action=allow \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP)"
# [END hypercomputer_gpu_tune_mixtral_slurm_firewall_rule]

# [START hypercomputer_gpu_tune_mixtral_slurm_ssh_login]
gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --tunnel-through-iap \
    --zone="${ZONE}"
    -- -t "export HF_TOKEN='${HF_TOKEN}'; bash -l"
# [END hypercomputer_gpu_tune_mixtral_slurm_ssh_login]

# [START hypercomputer_gpu_tune_mixtral_slurm_install_env_command]
# On the login node
srun \
  --job-name=env-setup \
  --nodes=1 \
  --ntasks=1 \
  --gpus-per-node=1 \
  --partition=a4high \
  bash ./install_environment.sh
# [END hypercomputer_gpu_tune_mixtral_slurm_install_env_command]

# ==============================================================================
# Start Fine-Tuning
# ==============================================================================

# [START hypercomputer_gpu_tune_mixtral_slurm_sbatch]
# On the login node
sbatch train-mixtral.sh
# [END hypercomputer_gpu_tune_mixtral_slurm_sbatch]

# [START hypercomputer_gpu_tune_mixtral_slurm_monitor_tail]
# On the login node:
tail -f mixtral-*.out mixtral-*.err
# [END hypercomputer_gpu_tune_mixtral_slurm_monitor_tail]

# ==============================================================================
# Monitor Workload
# ==============================================================================

# [START hypercomputer_gpu_tune_mixtral_slurm_monitor_workload_terminal]
open "https://console.cloud.google.com/monitoring/metrics-explorer?project=${PROJECT_ID}&pageState=%7B%22xyChart%22%3A%7B%22dataSets%22%3A%5B%7B%22timeSeriesFilter%22%3A%7B%22filter%22%3A%22metric.type%3D%5C%22agent.googleapis.com%2Fgpu%2Futilization%5C%22%20resource.type%3D%5C%22gce_instance%5C%22%22%2C%22perSeriesAligner%22%3A%22ALIGN_MEAN%22%7D%2C%22plotType%22%3A%22LINE%22%7D%5D%7D%7D"
# [END hypercomputer_gpu_tune_mixtral_slurm_monitor_workload_terminal]

# ==============================================================================
# Cleanup
# ==============================================================================

# [START hypercomputer_gpu_tune_mixtral_slurm_destroy_cluster]
./gcluster destroy "${DEPLOYMENT_NAME}" --auto-approve --robust
# [END hypercomputer_gpu_tune_mixtral_slurm_destroy_cluster]

# [START hypercomputer_gpu_tune_mixtral_slurm_destroy_image]
http://console.cloud.google.com/compute/images
# [END hypercomputer_gpu_tune_mixtral_slurm_destroy_image]
