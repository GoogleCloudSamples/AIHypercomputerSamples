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

if [[ -z "${WORK_DIR:-}" ]]; then
  echo "Error: WORK_DIR is not set. Please source 0_env.sh" >&2
  exit 1
fi

declare -r CLUSTER_TOOLKIT_VERSION="v1.97.0"
declare -r CLUSTER_TOOLKIT_URL="https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION}/gcluster_bundle_linux_amd64.tgz"
declare -r CLUSTER_TOOLKIT_PATH="${WORK_DIR}/cluster_toolkit"

# Debug environment
echo "[$(date)] DEBUG: PATH is: ${PATH}"
echo "[$(date)] DEBUG: which packer: $(which packer || echo 'NOT FOUND')"
if which packer &>/dev/null; then
  echo "[$(date)] DEBUG: packer version: $(packer --version)"
else
  echo "[$(date)] DEBUG: packer is NOT in PATH"
fi

echo "[$(date)] ==================== Starting Cluster Deployment ===================="

# 1. Create GCS bucket if it doesn't exist
echo "[$(date)] Creating GCS bucket gs://${BUCKET_NAME}..."
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
# [START hypercomputer_gpu_tune_gemma3_slurm_create_bucket]
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}"
# [END hypercomputer_gpu_tune_gemma3_slurm_create_bucket]
else
  echo "Bucket gs://${BUCKET_NAME} already exists."
fi  

# 2. Download cluster-toolkit release
if [[ ! -f "${CLUSTER_TOOLKIT_PATH}/gcluster" ]]; then
  echo "[$(date)] Downloading cluster-toolkit release..."
  curl -L -s -o "${WORK_DIR}/cluster_toolkit.tgz" "${CLUSTER_TOOLKIT_URL}" \
    && mkdir -p "${CLUSTER_TOOLKIT_PATH}"  \
    && tar -xf "${WORK_DIR}/cluster_toolkit.tgz" -C "${CLUSTER_TOOLKIT_PATH}" \
    && rm -f "${WORK_DIR}/cluster_toolkit.tgz"
else
  echo "[$(date)] gcluster already present. Skipping download..."
fi
export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 3. Configure deployment YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."

# [START hypercomputer_gpu_tune_gemma3_slurm_deploy_yaml]
MANIFEST_PATH="${CLUSTER_TOOLKIT_PATH}/examples/machine-learning/a4-highgpu-8g"
cat <<EOF > "${MANIFEST_PATH}/a4high-slurm-deployment.yaml"
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: ${BUCKET_NAME}

vars:
  deployment_name: ${CLUSTER_NAME}
  project_id: ${PROJECT_ID}
  region: ${REGION}
  zone: ${ZONE}
  a4h_cluster_size: 2
  a4h_reservation_name: ${RESERVATION_URL}
EOF
# [END hypercomputer_gpu_tune_gemma3_slurm_deploy_yaml]

# 4. Create, Patch, and Deploy cluster
echo "[$(date)] Creating deployment directory ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_tune_gemma3_slurm_create_tf]
gcluster create \
  -d "${MANIFEST_PATH}/a4high-slurm-deployment.yaml" \
  "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" \
  -o "${WORK_DIR}"
# [END hypercomputer_gpu_tune_gemma3_slurm_create_tf]

# [START hypercomputer_gpu_tune_gemma3_slurm_patch_tf]
echo "[$(date)] Patching Filestore deletion protection in ${CLUSTER_NAME}..."
sed -i '/deletion_protection = {/,/}/ { s/enabled = true/enabled = false/; /reason  = "Avoid data loss"/d; }' "${WORK_DIR}/${CLUSTER_NAME}/cluster-env/main.tf"
# [END hypercomputer_gpu_tune_gemma3_slurm_patch_tf]

echo "[$(date)] Deploying Slurm cluster from patched directory (this can take up to 35-45 minutes)..."
# [START hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster]
gcluster deploy "${WORK_DIR}/${CLUSTER_NAME}" --auto-approve
# [END hypercomputer_gpu_tune_gemma3_slurm_deploy_cluster]

echo "[$(date)] ==================== Cluster Deployment Complete. ===================="
