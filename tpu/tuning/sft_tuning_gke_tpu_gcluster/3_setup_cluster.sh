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
sed -i "s/n2-standard-8/e2-standard-8/" examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml

# Grant the GKE Node Pool Service Account storage.admin access to resolve the GCS bucket not found error
sed -i "s/- storage.objectViewer/- storage.admin/" examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
./gcluster deploy examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml \
    --vars "project_id=${PROJECT},deployment_name=${CLUSTER_NAME},region=${REGION},zone=${ZONE},num_slices=1,tpu_topology=4x8,authorized_cidr=0.0.0.0/0,reservation=${RESERVATION:-}" \
    --download-dependencies \
    --auto-approve -w

# Configure docker for pulling images
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

echo "[$(date)] ==================== Cluster deployment completed. ===================="
