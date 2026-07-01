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

source ./0_env.sh
set -euo pipefail

echo "[$(date)] ==================== Starting Cleanup... ===================="

# PROJECT_ID is dx-supercomputer-testing
# CLUSTER_NAME is miani-cluster
# BUCKET_NAME is miani-bucket-gpu-1
# REGION is us-west3
# ZONE is us-west3-c
# RESERVATION_URL is nvidia-b200-vjuar24msxrnf

# Prepare fake tfvars

# gpu/tuning/gemma3-slurm/miani-cluster/.ghpc/artifacts/cluster-env_outputs.tfvars

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r NETWORK="${CLUSTER_NAME}-net"

# echo "Temp Diir is ${TEMP_DIR}"
echo "Skipping cleanup..."
env
exit 0

cat << 'EOF' > "${BASEDIR}/${CLUSTER_NAME}/.ghpc/artifacts/cluster-env_outputs.tfvars"
    client_install_runner_gcs_checkpoints = null
    client_install_runner_gcs_model_serving = null
    client_install_runner_gcs_training_data = null
    mount_runner_gcs_checkpoints = null
    mount_runner_gcs_model_serving = null
    mount_runner_gcs_training_data = null
    network_storage_gcs_bucket = null
    network_storage_homefs = null
    subnetwork_interfaces_a4high-slurm-rdma-net = null
    subnetwork_self_link_a4high-slurm-net-0 = null
    subnetwork_self_link_a4high-slurm-net-1 = null
    subnetwork_stack_type_a4high-slurm-net-0 = null
EOF

# Remove firewall rules
echo "Manually remove firewall rules before destroying the cluster..."
RULES=$(gcloud compute firewall-rules list --filter="network:${NETWORK}" --project="${PROJECT_ID}" --format="value(name)")

if [ -n "${RULES}" ]; then
  echo "Deleting firewall rules:"
  echo "${RULES}"

  # Convert newlines to spaces for gcloud command                                                                                                                                                                  
  RULES_SPACED="$(echo "${RULES}" | tr '\n' ' ')"
  gcloud compute firewall-rules delete "${RULES_SPACED}" --project "${PROJECT_ID}" --quiet
else
  echo "No firewall rules found."
fi

# 1. Destroy Slurm cluster via cluster-toolkit
if [ -d "cluster-toolkit" ]; then
  echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
  cd cluster-toolkit/examples/machine-learning/a4-highgpu-8g
  ../../../gcluster destroy "${CLUSTER_NAME}" --auto-approve || true
  cd ../../../..
  
  echo "[$(date)] Removing cluster-toolkit directory..."
  rm -rf cluster-toolkit
else
  echo "cluster-toolkit directory not found, skipping cluster destruction."
fi

# 2. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${BUCKET_NAME}..."
gcloud storage buckets delete "gs://${BUCKET_NAME}" --quiet || true

echo "[$(date)] ==================== Cleanup Complete. ===================="
