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

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r SCRIPT_PATH BASEDIR
cd "${BASEDIR}"

# Define versions
declare -r TERRAFORM_VERSION="1.12.2"
declare -r CLUSTER_TOOLKIT_VERSION="v1.108.0"

declare -r TOOLS_DIR="${BASEDIR}/.tools"
declare -r CLUSTER_TOOLKIT_URL="https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION}/gcluster_bundle_linux_amd64.tgz"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"
mkdir -p "${TOOLS_DIR}"
export PATH="${TOOLS_DIR}:${PATH}"

install_hashicorp_tool() {
  local name="$1"
  local version="$2"
  if [[ -x "${TOOLS_DIR}/${name}" ]]; then
    return 0
  fi
  echo "[$(date)] Installing ${name} ${version}..."
  curl -f -sS -L --retry 3 --retry-all-errors \
    -o "${TOOLS_DIR}/${name}.zip" \
    "https://releases.hashicorp.com/${name}/${version}/${name}_${version}_linux_amd64.zip"
  python3 -m zipfile -e "${TOOLS_DIR}/${name}.zip" "${TOOLS_DIR}"
  chmod +x "${TOOLS_DIR}/${name}"
  rm -f "${TOOLS_DIR}/${name}.zip"
}

install_hashicorp_tool terraform "${TERRAFORM_VERSION}"

# Verify installation
echo "[$(date)] Terraform version: $(terraform --version)"

echo "[$(date)] ==================== Starting Cluster Deployment ===================="

# 1. Create GCS bucket if it doesn't exist
echo "[$(date)] Creating GCS bucket gs://${BUCKET_NAME}..."
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" &>/dev/null; then
# [START hypercomputer_gpu_tune_gemma4_slurm_create_bucket]
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_gpu_tune_gemma4_slurm_create_bucket]
else
  echo "Bucket gs://${BUCKET_NAME} already exists."
fi

# 2. Download cluster-toolkit release
if [[ ! -f "${CLUSTER_TOOLKIT_PATH}/gcluster" ]]; then
  echo "[$(date)] Downloading cluster-toolkit ${CLUSTER_TOOLKIT_VERSION}..."
  mkdir -p "${CLUSTER_TOOLKIT_PATH}"
  if ! curl -f -L -sS --retry 3 --retry-all-errors --retry-delay 5 \
      -o "${BASEDIR}/cluster_toolkit.tgz" "${CLUSTER_TOOLKIT_URL}"; then
    echo "[$(date)] Release download failed, retrying via the GitHub API..." >&2
    CLUSTER_TOOLKIT_ASSET_URL="$(curl -f -sS --retry 3 --retry-all-errors \
      "https://api.github.com/repos/GoogleCloudPlatform/cluster-toolkit/releases/tags/${CLUSTER_TOOLKIT_VERSION}" |
      python3 -c 'import json, sys; print(next(a["url"] for a in json.load(sys.stdin)["assets"] if a["name"] == "gcluster_bundle_linux_amd64.tgz"))')"
    curl -f -L -sS --retry 3 --retry-all-errors --retry-delay 5 \
      -H "Accept: application/octet-stream" \
      -o "${BASEDIR}/cluster_toolkit.tgz" "${CLUSTER_TOOLKIT_ASSET_URL}"
  fi
  tar -xf "${BASEDIR}/cluster_toolkit.tgz" -C "${CLUSTER_TOOLKIT_PATH}"
  rm -f "${BASEDIR}/cluster_toolkit.tgz"
else
  echo "[$(date)] gcluster already present. Skipping download..."
fi
export PATH="${CLUSTER_TOOLKIT_PATH}:${PATH}"
gcluster --version

# 3. Configure deployment YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."

# [START hypercomputer_gpu_tune_gemma4_slurm_deploy_yaml]
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
  a4h_cluster_size: ${NUM_NODES}
  a4h_reservation_name: ${RESERVATION_URL}
EOF
# [END hypercomputer_gpu_tune_gemma4_slurm_deploy_yaml]

echo "[$(date)] Patching a4high-slurm-blueprint.yaml (Ansible installation, ResumeTimeout)..."
# [START hypercomputer_gpu_tune_gemma4_slurm_patch_blueprint]
sed -i \
  -e 's/^\([[:space:]]*\)install_ansible: false/\1install_ansible: true/' \
  -e 's/^\([[:space:]]*\)ResumeTimeout: 1200/\1ResumeTimeout: 1800/' \
  "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml"
# [END hypercomputer_gpu_tune_gemma4_slurm_patch_blueprint]

if grep -q 'install_ansible: false' "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" ||
    ! grep -q 'ResumeTimeout: 1800' "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml"; then
  echo "Error: could not patch ${MANIFEST_PATH}/a4high-slurm-blueprint.yaml." >&2
  exit 1
fi

# 4. Create and deploy cluster
echo "[$(date)] Creating deployment directory ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_tune_gemma4_slurm_create_tf]
gcluster create \
  -d "${MANIFEST_PATH}/a4high-slurm-deployment.yaml" \
  "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" \
  -w
# [END hypercomputer_gpu_tune_gemma4_slurm_create_tf]

echo "[$(date)] Deploying Slurm cluster (this can take up to 45-60 minutes)..."
# [START hypercomputer_gpu_tune_gemma4_slurm_deploy_cluster]
gcluster deploy "${CLUSTER_NAME}" --auto-approve
# [END hypercomputer_gpu_tune_gemma4_slurm_deploy_cluster]

echo "[$(date)] ==================== Cluster Deployment Complete. ===================="
