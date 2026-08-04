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

echo "[$(date)] ==================== Downloading gcluster blueprint... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_download_blueprint]
wget https://raw.githubusercontent.com/GoogleCloudPlatform/cluster-toolkit/refs/heads/develop/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml -O gke-tpu-v6e-advanced.yaml
wget https://raw.githubusercontent.com/GoogleCloudPlatform/cluster-toolkit/refs/heads/develop/examples/gke-tpu-v6e/kueue-configuration.yaml.tftpl -O kueue-configuration.yaml.tftpl
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_download_blueprint]

echo "[$(date)] ==================== Configuring blueprint... ===================="
# We inject the environment variables into the downloaded YAML blueprint using sed.
sed -i "s/project_id:.*/project_id: ${PROJECT}/" gke-tpu-v6e-advanced.yaml
sed -i "s/deployment_name:.*/deployment_name: ${CLUSTER_NAME}/" gke-tpu-v6e-advanced.yaml
sed -i "s/region:.*/region: ${REGION}/" gke-tpu-v6e-advanced.yaml
sed -i "s/zone:.*/zone: ${ZONE}/" gke-tpu-v6e-advanced.yaml
sed -i "s/num_slices:.*/num_slices: 1/" gke-tpu-v6e-advanced.yaml
sed -i "s/tpu_topology:.*/tpu_topology: 4x8/" gke-tpu-v6e-advanced.yaml
sed -i "s|authorized_cidr:.*|authorized_cidr: 0.0.0.0/0|" gke-tpu-v6e-advanced.yaml
# This line can be uncommented if you need to use e2-standard-8 instead of n2-standard-8 due to capacity issues
# sed -i "s/n2-standard-8/e2-standard-8/" gke-tpu-v6e-advanced.yaml

if [ -z "$RESERVATION" ]; then
    sed -i "s/reservation:.*/reservation: ''/" gke-tpu-v6e-advanced.yaml
else
    sed -i "s/reservation:.*/reservation: ${RESERVATION}/" gke-tpu-v6e-advanced.yaml
fi

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_create_cluster]
gcluster deploy gke-tpu-v6e-advanced.yaml -l IGNORE --auto-approve -w

# Configure docker and IAM for the service accounts created by cluster-toolkit
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_create_cluster]

echo "[$(date)] ==================== Cluster deployment completed. ===================="
