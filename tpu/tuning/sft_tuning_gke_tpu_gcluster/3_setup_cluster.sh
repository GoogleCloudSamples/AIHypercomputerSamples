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

echo "[$(date)] ==================== Preparing blueprint workspace ===================="
mkdir -p tmp
cp examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml tmp/gke-tpu-v6e-advanced.yaml
echo "[$(date)] ==================== Blueprint workspace prepared ====================="

echo "[$(date)] ==================== Configuring blueprint... ===================="
# Grant the GKE Node Pool Service Account storage.admin access to resolve the GCS bucket not found error
sed -i "s/- storage.objectViewer/- storage.admin/" tmp/gke-tpu-v6e-advanced.yaml

# Change n2-standard-8 to e2-standard-8 to avoid GCE_STOCKOUT in some regions
sed -i "s/n2-standard-8/e2-standard-8/" tmp/gke-tpu-v6e-advanced.yaml

# Pin system node pool to a single zone to avoid cross-zone stockouts
sed -i '/system_node_pool_machine_type/a \      system_node_pool_zones: [$(vars.zone)]' tmp/gke-tpu-v6e-advanced.yaml

echo "[$(date)] ==================== Configuring IAM for default Compute SA... ===================="
gcloud services enable compute.googleapis.com --project="${PROJECT:?}"

PROJECT_NUMBER=$(gcloud projects describe "${PROJECT:?}" --format="value(projectNumber)")
BUILD_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for role in roles/storage.objectViewer roles/logging.logWriter roles/artifactregistry.writer; do
  gcloud projects add-iam-policy-binding "${PROJECT:?}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="${role}" --quiet > /dev/null
done

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
./gcluster deploy tmp/gke-tpu-v6e-advanced.yaml \
    --vars "project_id=${PROJECT:?},deployment_name=${CLUSTER_NAME:?},region=${REGION:?},zone=${ZONE:?},num_slices=1,tpu_topology=4x8,authorized_cidr=0.0.0.0/0,reservation=${RESERVATION:-}" \
    --download-dependencies \
    -l IGNORE \
    --auto-approve -w

# Fetch GKE cluster credentials for kubectl
gcloud container clusters get-credentials "${CLUSTER_NAME:?}" --location="${REGION:?}" --project="${PROJECT:?}"

# Configure gcluster Defaults
./gcluster job config set project "${PROJECT:?}"
./gcluster job config set cluster "${CLUSTER_NAME:?}"
./gcluster job config set location "${REGION:?}"

# Configure docker for pulling images
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker "${REGION:?}-docker.pkg.dev" --quiet

# Grant storage.admin to GKE service accounts
gcloud projects add-iam-policy-binding "${PROJECT:?}" --member="serviceAccount:${CLUSTER_NAME:?}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet || true
gcloud projects add-iam-policy-binding "${PROJECT:?}" --member="serviceAccount:${CLUSTER_NAME:?}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet || true

echo "[$(date)] ==================== Cluster deployment completed. ===================="

echo "[$(date)] ==================== Waiting for controllers rollouts ===================="
# Wait for deployments to exist before checking rollout status to avoid race conditions
for i in {1..30}; do
  if kubectl get deployment/jobset-controller -n jobset-system &>/dev/null && \
     kubectl get deployment/kueue-controller-manager -n kueue-system &>/dev/null; then
    break
  fi
  sleep 2
done

kubectl rollout status deployment/jobset-controller -n jobset-system --timeout=180s
kubectl rollout status deployment/kueue-controller-manager -n kueue-system --timeout=180s
