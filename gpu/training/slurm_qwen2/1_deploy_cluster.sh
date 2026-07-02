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

# 1. Download cluster-toolkit release
declare -r CLUSTER_TOOLKIT_VERSION="v1.94.0"
declare -r CLUSTER_TOOLKIT_URL="https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION}/gcluster_bundle_linux_amd64.tgz"
declare -r CLUSTER_TOOLKIT_PATH="$(realpath "gcluster_release/")"

echo "[$(date)] ==================== Starting Cluster Deployment ===================="

# 2. Create Google Cloud Storage Bucket (if it doesn't exist)
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

# 3. Download cluster-toolkit release
curl -L -o gcluster.tgz "${CLUSTER_TOOLKIT_URL}" \
  && mkdir -p gcluster_release  \
  && tar -xf gcluster.tgz -C gcluster_release \
  && rm -f gcluster.tgz \
  && mv gcluster_release/gcluster . \
  && ./gcluster --version

# 3. Configure deployment YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."
declare -r MANIFEST_PATH="${CLUSTER_TOOLKIT_PATH}/examples/machine-learning/a4-highgpu-8g"

# [START hypercomputer_gpu_train_qwen2_slurm_download_deployment_yaml]
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
./gcluster create \
  -d "${MANIFEST_PATH}/a4high-slurm-deployment.yaml" \
  "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" \
  -o "${CLUSTER_NAME}"
# [END hypercomputer_gpu_train_qwen2_slurm_download_gcluster_create]

echo "[$(date)] Step 4b: Modifying the Packer version requirements in the generated files..."
find . -type f -name "versions.pkr.hcl" -exec sed -i 's/>= 1.15.3/>= 1.15.0/g' {} +

echo "[$(date)] Patching Filestore deletion protection in ${CLUSTER_NAME}..."
sed -i '/deletion_protection = {/,/}/ { s/enabled = true/enabled = false/; /reason  = "Avoid data loss"/d; }' "${CLUSTER_NAME}/${CLUSTER_NAME}/cluster-env/main.tf"

echo "[$(date)] Step 4c: Launching the deployment from the folder (35-40 minutes)..."
# [START hypercomputer_gpu_train_qwen2_slurm_download_deploy_cluster]
./gcluster deploy "${CLUSTER_NAME}/${CLUSTER_NAME}" --auto-approve
# [END hypercomputer_gpu_train_qwen2_slurm_download_deploy_cluster]

echo "[$(date)] ==================== Cluster Deployment Complete! ===================="
