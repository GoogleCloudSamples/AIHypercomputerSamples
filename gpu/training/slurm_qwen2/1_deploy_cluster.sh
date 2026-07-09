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

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"

declare -r CLUSTER_TOOLKIT_VERSION="v1.94.0"
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
echo "Checking if bucket gs://$GCS_BUCKET already exists..."

if gcloud storage buckets describe "gs://$GCS_BUCKET" > /dev/null 2>&1; then
    echo "Bucket gs://$GCS_BUCKET already exists. Skipping creation."
else
    echo "Bucket does not exist. Creating bucket gs://$GCS_BUCKET..."
    # [START hypercomputer_gpu_train_qwen2_slurm_create_gcs_bucket]
      gcloud storage buckets create "gs://${GCS_BUCKET}" \
        --project="${PROJECT_ID}"
    # [END hypercomputer_gpu_train_qwen2_slurm_create_gcs_bucket]
fi

echo "Verifying bucket creation..."
if gcloud storage buckets describe "gs://${GCS_BUCKET}" > /dev/null 2>&1; then
    echo "Success! Bucket gs://${GCS_BUCKET} is created and accessible."
else
    echo "Error: Bucket gs://${GCS_BUCKET} could not be found or is inaccessible."
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

# 3. Configure deployment YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."
# [START hypercomputer_gpu_train_qwen2_slurm_download_deployment_yaml]
MANIFEST_PATH="${CLUSTER_TOOLKIT_PATH}/examples/machine-learning/a4-highgpu-8g"
cat <<EOF > "${MANIFEST_PATH}/a4high-slurm-deployment.yaml"
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: ${GCS_BUCKET}

vars:
  deployment_name: ${CLUSTER_NAME}
  project_id: ${PROJECT_ID}
  region: ${REGION}
  zone: ${ZONE}
  a4h_cluster_size: 2
  a4h_reservation_name: ${RESERVATION_URL}
EOF
# [END hypercomputer_gpu_train_qwen2_slurm_download_deployment_yaml]

# 4. Deploy cluster

echo "[$(date)] Step 4a: Generating the directory structure..."
# [START hypercomputer_gpu_train_qwen2_slurm_download_gcluster_create]
gcluster create \
  -d "${MANIFEST_PATH}/a4high-slurm-deployment.yaml" \
  "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" \
  -o "${CLUSTER_NAME}"
# [END hypercomputer_gpu_train_qwen2_slurm_download_gcluster_create]

echo "[$(date)] Step 4b: Modifying the Packer version requirements in the generated files..."
# [START hypercomputer_gpu_train_qwen2_slurm_manifests_packer]
find . -type f -name "versions.pkr.hcl" -exec sed -i 's/>= 1.15.3/>= 1.15.0/g' {} +
# [END hypercomputer_gpu_train_qwen2_slurm_manifests_packer]

echo "[$(date)] Patching Filestore deletion protection in ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_train_qwen2_slurm_manifests_filestore]
sed -i '/deletion_protection = {/,/}/ { s/enabled = true/enabled = false/; /reason  = "Avoid data loss"/d; }' "${CLUSTER_NAME}/${CLUSTER_NAME}/cluster-env/main.tf"
# [END hypercomputer_gpu_train_qwen2_slurm_manifests_filestore]

echo "[$(date)] Step 4c: Launching the deployment from the folder..."
# [START hypercomputer_gpu_train_qwen2_slurm_download_deploy_cluster]
gcluster deploy "${CLUSTER_NAME}/${CLUSTER_NAME}" --auto-approve
# [END hypercomputer_gpu_train_qwen2_slurm_download_deploy_cluster]

echo "[$(date)] ==================== Cluster Deployment Complete! ===================="
