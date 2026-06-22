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

echo "[$(date)] ==================== Starting Cluster Deployment ===================="

# 1. Create GCS bucket if it doesn't exist
echo "[$(date)] Creating GCS bucket gs://${BUCKET_NAME}..."
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" --project="${PROJECT_ID}"
else
  echo "Bucket gs://${BUCKET_NAME} already exists."
fi

# 2. Clone cluster-toolkit
echo "[$(date)] Cloning cluster-toolkit..."
if [ ! -d "cluster-toolkit" ]; then
  git clone https://github.com/GoogleCloudPlatform/cluster-toolkit.git
else
  echo "cluster-toolkit directory already exists, skipping clone."
fi

# 3. Build gcluster
echo "[$(date)] Building gcluster..."
cd cluster-toolkit
make
cd ..

# 4. Configure deployment YAML
echo "[$(date)] Configuring a4high-slurm-deployment.yaml..."
cat <<EOF > cluster-toolkit/examples/machine-learning/a4-highgpu-8g/a4high-slurm-deployment.yaml
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

# 5. Deploy cluster
echo "[$(date)] Deploying Slurm cluster (this can take up to 35-40 minutes)..."
cd cluster-toolkit
./gcluster deploy -d examples/machine-learning/a4-highgpu-8g/a4high-slurm-deployment.yaml examples/machine-learning/a4-highgpu-8g/a4high-slurm-blueprint.yaml --auto-approve
cd ..

echo "[$(date)] ==================== Cluster Deployment Complete ===================="
