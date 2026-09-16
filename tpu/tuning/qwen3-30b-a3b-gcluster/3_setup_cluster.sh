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
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
echo "[$(date)] ==================== Configuring blueprint... ===================="
# Change n2-standard-8 to e2-standard-8
sed -i "s/n2-standard-8/e2-standard-8/" examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
./gcluster deploy examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml \
    --vars "project_id=${PROJECT},deployment_name=${CLUSTER_NAME},region=${REGION},zone=${ZONE},num_slices=${CLUSTER_NODEPOOL_COUNT},tpu_topology=${TOPOLOGY},authorized_cidr=0.0.0.0/0,reservation=${RESERVATION:-}" \
    --download-dependencies \
    -l IGNORE --auto-approve -w

# Fetch GKE cluster credentials for kubectl
gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${REGION} --project=${PROJECT}

# Configure docker and IAM for the service accounts created by cluster-toolkit
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]

echo "Waiting for any pending cluster operations to complete..."
while true; do
  OPS=$(gcloud container operations list --filter="status=RUNNING AND targetLink ~ ${CLUSTER_NAME}" --format="value(name)" 2>/dev/null || true)
  if [ -z "$OPS" ]; then
    break
  fi
  echo "Cluster operations still running: ${OPS}. Waiting 15s..."
  sleep 15
done

echo "Waiting for JobSet and Kueue controllers to be ready..."
kubectl -n jobset-system rollout status deployment/jobset-controller-manager --timeout=300s 2>/dev/null || true
kubectl -n kueue-system rollout status deployment/kueue-controller-manager --timeout=300s 2>/dev/null || true

echo "[$(date)] ==================== Cluster deployment completed. ===================="
