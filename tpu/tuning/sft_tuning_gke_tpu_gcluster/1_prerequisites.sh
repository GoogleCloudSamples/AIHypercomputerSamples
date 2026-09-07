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

echo "[$(date)] ==================== Installing Prerequisites ===================="
# [START hypercomputer_tpu_sft_gcluster_install_dependencies]
wget -qO- https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/latest/download/gcluster_bundle_linux_amd64.tgz | tar -xz
# [END hypercomputer_tpu_sft_gcluster_install_dependencies]

if [[ -n "${PROJECT:-}" ]]; then
  echo "[$(date)] ==================== Preparing Project IAM Roles ===================="
  # The GKE TPU v6e blueprint uses GCS Fuse CSI Storage Profiles which requires custom IAM role gke.gcsfuse.profileUser
  if ! gcloud iam roles describe gke.gcsfuse.profileUser --project="${PROJECT}" >/dev/null 2>&1; then
    echo "Creating custom IAM role gke.gcsfuse.profileUser in project ${PROJECT}..."
    gcloud iam roles create gke.gcsfuse.profileUser \
      --project="${PROJECT}" \
      --title="GKE GCSFuse Profile User" \
      --description="Allows scanning GCS buckets for objects, retrieving bucket metadata, and creating Anywhere Caches." \
      --permissions="storage.objects.list,storage.buckets.get,storage.anywhereCaches.create,storage.anywhereCaches.get,storage.anywhereCaches.list,storage.anywhereCaches.update"
  else
    echo "Custom IAM role gke.gcsfuse.profileUser already exists in project ${PROJECT}."
  fi

  PROJECT_NUMBER=$(gcloud projects describe "${PROJECT}" --format="value(projectNumber)" 2>/dev/null || true)
  if [[ -n "${PROJECT_NUMBER}" ]]; then
    echo "Binding gke.gcsfuse.profileUser role to GKE service agent in project ${PROJECT}..."
    gcloud projects add-iam-policy-binding "${PROJECT}" \
      --member="serviceAccount:service-${PROJECT_NUMBER}@container-engine-robot.iam.gserviceaccount.com" \
      --role="projects/${PROJECT}/roles/gke.gcsfuse.profileUser" --quiet || true
  fi
fi

echo "[$(date)] ==================== Prerequisites Installed ===================="
