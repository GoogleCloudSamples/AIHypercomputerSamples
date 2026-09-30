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

# Define versions
export TERRAFORM_VERSION="1.12.2"
export PACKER_VERSION="1.15.3"
export INSTALL_TEMP_DIR="/tmp/bin_dependencies"
mkdir -p "${INSTALL_TEMP_DIR}"

# Install Terraform
if ! command -v terraform &> /dev/null; then
  echo "[$(date)] Installing Terraform..."
  curl -f -s -L \
    -o "${INSTALL_TEMP_DIR}/terraform.zip" \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
  python3 -m zipfile -e "${INSTALL_TEMP_DIR}/terraform.zip" "${INSTALL_TEMP_DIR}"
  sudo mv "${INSTALL_TEMP_DIR}/terraform" /usr/local/bin/
  sudo chmod +x /usr/local/bin/terraform
  rm -f "${INSTALL_TEMP_DIR}/terraform.zip"
fi

# Install Packer
if ! command -v packer &> /dev/null; then
  echo "[$(date)] Installing Packer..."
  curl -f -s -L \
    -o "${INSTALL_TEMP_DIR}/packer.zip" \
    "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"
  python3 -m zipfile -e "${INSTALL_TEMP_DIR}/packer.zip" "${INSTALL_TEMP_DIR}"
  sudo mv "${INSTALL_TEMP_DIR}/packer" /usr/local/bin/
  sudo chmod +x /usr/local/bin/packer
  rm -f "${INSTALL_TEMP_DIR}/packer.zip"
fi

# Verify installation
echo "[$(date)] Terraform version: $(terraform --version)"
echo "[$(date)] Packer version: $(packer --version)"

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"

declare -r CLUSTER_TOOLKIT_VERSION="v1.97.0"
declare -r CLUSTER_TOOLKIT_URL="https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION}/gcluster_bundle_linux_amd64.tgz"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"

# Debug environment
echo "[$(date)] DEBUG: PATH is: ${PATH}"
echo "[$(date)] DEBUG: which packer: $(which packer || echo 'NOT FOUND')"
if which packer &>/dev/null; then
  echo "[$(date)] DEBUG: packer version: $(packer --version)"
else
  echo "[$(date)] DEBUG: packer is NOT in PATH"
fi

echo "[$(date)] ==================== Starting Cluster Deployment ===================="

# 1. Create Google Cloud Storage Bucket (if it doesn't exist)
echo "Checking if bucket gs://$BUCKET_NAME already exists..."

if gcloud storage buckets describe "gs://$BUCKET_NAME" > /dev/null 2>&1; then
    echo "Bucket gs://$BUCKET_NAME already exists. Skipping creation."
else
    echo "Bucket does not exist. Creating bucket gs://$BUCKET_NAME..."
    # [START hypercomputer_gpu_tune_mixtral_slurm_gcs_bucket]
      gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --project="${PROJECT_ID}"
    # [END hypercomputer_gpu_tune_mixtral_slurm_gcs_bucket]
fi

echo "Verifying bucket creation..."
if gcloud storage buckets describe "gs://${BUCKET_NAME}" > /dev/null 2>&1; then
    echo "Success! Bucket gs://${BUCKET_NAME} is created and accessible."
else
    echo "Error: Bucket gs://${BUCKET_NAME} could not be found or is inaccessible."
    exit 1
fi

# 2. Download cluster-toolkit release
if [[ ! -f "${CLUSTER_TOOLKIT_PATH}/gcluster" ]]; then
  echo "[$(date)] Downloading cluster-toolkit release..."
  curl -L -s -o "${BASEDIR}/cluster_toolkit.tgz" "${CLUSTER_TOOLKIT_URL}" \
    && mkdir -p "${CLUSTER_TOOLKIT_PATH}"  \
    && tar -xf "${BASEDIR}/cluster_toolkit.tgz" -C "${CLUSTER_TOOLKIT_PATH}" \
    && rm -f "${BASEDIR}/cluster_toolkit.tgz"
else
  echo "[$(date)] gcluster already present. Skipping download..."
fi

ln -sf "${CLUSTER_TOOLKIT_PATH}/gcluster" "${BASEDIR}/gcluster"

export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 3. Configure deployment and blueprint YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."
# [START hypercomputer_gpu_tune_mixtral_slurm_deployment_yaml]
MANIFEST_PATH="${CLUSTER_TOOLKIT_PATH}/examples/machine-learning/a4-highgpu-8g"
cat <<EOF > "${MANIFEST_PATH}/a4high-slurm-deployment.yaml"
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: ${BUCKET_NAME}

vars:
  deployment_name: ${DEPLOYMENT_NAME}
  project_id: ${PROJECT_ID}
  region: ${REGION}
  zone: ${ZONE}
  a4h_cluster_size: 2
  a4h_reservation_name: ${RESERVATION_NAME}
EOF
# [END hypercomputer_gpu_tune_mixtral_slurm_deployment_yaml]

YAML_PATH="${CLUSTER_TOOLKIT_PATH}/examples/machine-learning/a4-highgpu-8g/a4high-slurm-blueprint.yaml"
bash ./modify_blueprint.sh "$YAML_PATH"

# 4. Deploy cluster

echo "[$(date)] Launching the deployment..."
# [START hypercomputer_gpu_tune_mixtral_slurm_deploy_cluster]
./gcluster deploy \
  -d "${MANIFEST_PATH}/a4high-slurm-deployment.yaml" \
  "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" \
  --auto-approve
# [END hypercomputer_gpu_tune_mixtral_slurm_deploy_cluster]

echo "[$(date)] ==================== Cluster Deployment Complete! ===================="
