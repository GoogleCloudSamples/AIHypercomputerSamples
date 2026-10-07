#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

echo "[$(date)] ==================== Preparing gcluster blueprint... ===================="
echo "[$(date)] ==================== Configuring blueprint... ===================="

# Change n2-standard-8 to e2-standard-8
TMP_DIR=$(mktemp -d)
BLUEPRINT_FILE="${TMP_DIR}/gke-tpu-v6e-advanced.yaml"

cp ./examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml "${BLUEPRINT_FILE}"
sed -i "s/n2-standard-8/e2-standard-8/" "${BLUEPRINT_FILE}"
sed -i '/system_node_pool_machine_type/a \      system_node_pool_zones: [$(vars.zone)]' "${BLUEPRINT_FILE}"

echo "[$(date)] ==================== Configuring IAM for default Compute SA... ===================="
# Ensure Compute API is enabled so the default Compute Service Account exists
gcloud services enable compute.googleapis.com --project="$PROJECT"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for role in roles/storage.objectViewer roles/logging.logWriter roles/artifactregistry.writer; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${COMPUTE_SA}" \
    --role="$role" --quiet
done

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
./gcluster deploy "${BLUEPRINT_FILE}" \
    --vars "project_id=${PROJECT},deployment_name=${CLUSTER_NAME},region=${REGION},zone=${ZONE},num_slices=${CLUSTER_NODEPOOL_COUNT},tpu_topology=${TOPOLOGY},authorized_cidr=0.0.0.0/0,reservation=${RESERVATION:-}" \
    --download-dependencies \
    -l IGNORE --auto-approve -w

# Fetch GKE cluster credentials for kubectl
gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${REGION} --project=${PROJECT}

# Configure gcluster Defaults
./gcluster job config set project "${PROJECT}"
./gcluster job config set cluster "${CLUSTER_NAME}"
./gcluster job config set location "${REGION}"

# Configure docker and IAM for the service accounts created by cluster-toolkit
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet

echo "[$(date)] ==================== Cluster deployment completed. ===================="
