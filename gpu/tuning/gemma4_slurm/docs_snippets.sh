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

# ==============================================================================
# Prerequisites
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma4_slurm_adc_login]
gcloud auth application-default login
# [END hypercomputer_gpu_tune_gemma4_slurm_adc_login]

# [START hypercomputer_gpu_tune_gemma4_slurm_enable_oslogin]
gcloud compute project-info add-metadata \
    --metadata=enable-oslogin=TRUE \
    --project=PROJECT_ID
# [END hypercomputer_gpu_tune_gemma4_slurm_enable_oslogin]

# ==============================================================================
# Prepare Environment
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma4_slurm_toolkit_download]
# Find all available releases at: https://github.com/GoogleCloudPlatform/cluster-toolkit/releases
# Set the desired version TAG (e.g., v1.108.0)
export CLUSTER_TOOLKIT_TAG=v1.108.0

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
# [END hypercomputer_gpu_tune_gemma4_slurm_toolkit_download]

# [START hypercomputer_gpu_tune_gemma4_slurm_install_toolkit]
# Download and extract the platform-specific bundle
curl -fLO "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_TAG}/gcluster_bundle_${OS}_${ARCH}.tgz"
mkdir -p cluster-toolkit
tar -xzf "gcluster_bundle_${OS}_${ARCH}.tgz" -C cluster-toolkit/
rm -f "gcluster_bundle_${OS}_${ARCH}.tgz"
# [END hypercomputer_gpu_tune_gemma4_slurm_install_toolkit]

# [START hypercomputer_gpu_tune_gemma4_slurm_toolkit_setpath]
export CLUSTER_TOOLKIT_PATH="${PWD}/cluster-toolkit"
export PATH="${CLUSTER_TOOLKIT_PATH}:${PATH}"
gcluster --version
# [END hypercomputer_gpu_tune_gemma4_slurm_toolkit_setpath]


# ==============================================================================
# Prepare Workload
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma4_slurm_ssh_login]
gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --tunnel-through-iap \
    --zone="${ZONE}" \
    -- -t "export HF_TOKEN='${HF_TOKEN}' NUM_NODES='${NUM_NODES}' MODEL_ID='${MODEL_ID}'; bash -l"
# [END hypercomputer_gpu_tune_gemma4_slurm_ssh_login]

# [START hypercomputer_gpu_tune_gemma4_slurm_install_tools]
chmod +x install_environment.sh
./install_environment.sh
# [END hypercomputer_gpu_tune_gemma4_slurm_install_tools]

# ==============================================================================
# Start Fine-Tuning
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma4_slurm_sbatch]
JOB_ID="$(sbatch --nodes="${NUM_NODES}" submit.slurm 2>&1 \
  | tee /dev/tty \
  | grep -oP 'Submitted batch job \K\d+')"
# [END hypercomputer_gpu_tune_gemma4_slurm_sbatch]

# [START hypercomputer_gpu_tune_gemma4_slurm_monitor_tail]
tail -f "slurm-${JOB_ID}.out" "slurm-${JOB_ID}.err"
# [END hypercomputer_gpu_tune_gemma4_slurm_monitor_tail]

# ==============================================================================
# Monitor Workload
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma4_slurm_view_metrics]
echo "https://console.cloud.google.com/monitoring/metrics-explorer?project=${PROJECT_ID}&pageState=%7B%22xyChart%22%3A%7B%22dataSets%22%3A%5B%7B%22timeSeriesFilter%22%3A%7B%22filter%22%3A%22metric.type%3D%5C%22agent.googleapis.com%2Fgpu%2Futilization%5C%22%20resource.type%3D%5C%22gce_instance%5C%22%22%2C%22perSeriesAligner%22%3A%22ALIGN_MEAN%22%7D%2C%22plotType%22%3A%22LINE%22%7D%5D%7D%7D"
# [END hypercomputer_gpu_tune_gemma4_slurm_view_metrics]

# ==============================================================================
# Cleanup
# ==============================================================================

# [START hypercomputer_gpu_tune_gemma4_slurm_destroy_cluster]
gcluster destroy "${CLUSTER_NAME}" --auto-approve
# [END hypercomputer_gpu_tune_gemma4_slurm_destroy_cluster]

# [START hypercomputer_gpu_tune_gemma4_slurm_delete_bucket]
gcloud storage rm --recursive "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}"
# [END hypercomputer_gpu_tune_gemma4_slurm_delete_bucket]
