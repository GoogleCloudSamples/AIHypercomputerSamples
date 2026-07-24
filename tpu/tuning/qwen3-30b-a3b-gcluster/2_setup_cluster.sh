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

echo "[$(date)] ==================== Creating Cluster... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
wget -N https://raw.githubusercontent.com/GoogleCloudPlatform/cluster-toolkit/refs/heads/develop/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml
wget -N https://raw.githubusercontent.com/GoogleCloudPlatform/cluster-toolkit/refs/heads/develop/examples/gke-tpu-v6e/kueue-configuration.yaml.tftpl

gcluster create --blueprint gke-tpu-v6e-advanced.yaml \
  --vars project_id=${PROJECT},region=${REGION},zone=${ZONE},deployment_name=${CLUSTER_NAME},reservation=${RESERVATION},num_slices=${CLUSTER_NODEPOOL_COUNT},tpu_topology=${TOPOLOGY},authorized_cidr=0.0.0.0/0

gcluster deploy ${CLUSTER_NAME} -l IGNORE --auto-approve -w

gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --location=${REGION} \
  --project ${PROJECT}

gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
echo "[$(date)] ==================== Cluster created. ===================="
