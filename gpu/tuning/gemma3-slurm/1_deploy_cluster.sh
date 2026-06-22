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

declare -r CLUSTER_TOOLKIT_VERSION="v1.94.0"
declare -r CLUSTER_TOOLKIT_URL="https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION}/gcluster_bundle_linux_amd64.tgz"
declare -r CLUSTER_TOOLKIT_PATH="$(realpath "gcluster_release/")"

echo "[$(date)] ==================== Starting Cluster Deployment ===================="

# 1. Create GCS bucket if it doesn't exist
echo "[$(date)] Creating GCS bucket gs://${BUCKET_NAME}..."
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" --project="${PROJECT_ID}"
else
  echo "Bucket gs://${BUCKET_NAME} already exists."
fi

# 2. Download cluster-toolkit release
curl -L -o gcluster.tgz "${CLUSTER_TOOLKIT_URL}" \
  && mkdir -p gcluster_release  \
  && tar -xf gcluster.tgz -C gcluster_release \
  && rm -f gcluster.tgz \
  && mv gcluster_release/gcluster . \
  && ./gcluster --version

# 3. Configure deployment YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."
declare -r MANIFEST_PATH="${CLUSTER_TOOLKIT_PATH}/examples/machine-learning/a4-highgpu-8g"

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

# 4. Deploy cluster
echo "[$(date)] Deploying Slurm cluster (this can take up to 35-40 minutes)..."
./gcluster deploy -d "${MANIFEST_PATH}/a4high-slurm-deployment.yaml" "${MANIFEST_PATH}/a4high-slurm-blueprint.yaml" --auto-approve

echo "[$(date)] ==================== Cluster Deployment Complete! ===================="
