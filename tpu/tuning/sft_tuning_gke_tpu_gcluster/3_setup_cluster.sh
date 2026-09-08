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

echo "[$(date)] ==================== Configuring blueprint... ===================="
# This line can be uncommented if you need to use e2-standard-8 instead of n2-standard-8 due to capacity issues
#sed -i "s/n2-standard-8/e2-standard-8/" examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml

# Grant the GKE Node Pool Service Account storage.admin access to resolve the GCS bucket not found error
sed -i "s/- storage.objectViewer/- storage.admin/" examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml

# Ensure custom IAM role gke.gcsfuse.profileUser exists for GCS Fuse Storage Profiles
if ! gcloud iam roles describe gke.gcsfuse.profileUser --project="${PROJECT}" >/dev/null 2>&1; then
  echo "Creating custom IAM role gke.gcsfuse.profileUser in project ${PROJECT}..."
  gcloud iam roles create gke.gcsfuse.profileUser \
    --project="${PROJECT}" \
    --title="GKE GCSFuse Profile User" \
    --description="Allows scanning GCS buckets for objects, retrieving bucket metadata, and creating Anywhere Caches." \
    --permissions="storage.objects.list,storage.buckets.get,storage.anywhereCaches.create,storage.anywhereCaches.get,storage.anywhereCaches.list,storage.anywhereCaches.update"
fi

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
./gcluster deploy examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml \
    --vars "project_id=${PROJECT},deployment_name=${CLUSTER_NAME},region=${REGION},zone=${ZONE},num_slices=1,tpu_topology=4x8,authorized_cidr=0.0.0.0/0,reservation=${RESERVATION:-}" \
    --download-dependencies \
    -l IGNORE \
    --auto-approve -w

# Fetch GKE cluster credentials for kubectl
gcloud container clusters get-credentials "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}"

# Configure docker for pulling images
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Grant storage.admin to GKE service accounts
gcloud projects add-iam-policy-binding "${PROJECT}" --member="serviceAccount:${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet || true
gcloud projects add-iam-policy-binding "${PROJECT}" --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet || true

echo "[$(date)] ==================== Cluster deployment completed. ===================="
