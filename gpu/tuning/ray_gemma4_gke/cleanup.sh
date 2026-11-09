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

# [START hypercomputer_gpu_tune_gemma3_ray_cleanup]
kubectl delete -f ray_job.yaml --ignore-not-found=true || true
echo "[$(date)] ==================== Ray job deleted. ===================="

kubectl delete configmap ray-job-cm --ignore-not-found=true || true
echo "[$(date)] ==================== ConfigMap deleted. ===================="

kubectl delete -f ray_cluster.yaml --ignore-not-found=true || true
echo "[$(date)] ==================== Ray cluster deleted. ===================="

gcloud container clusters delete $CLUSTER_NAME \
    --region=$REGION --quiet || true
echo "[$(date)] ==================== GKE cluster deleted. ===================="

if gcloud storage buckets describe gs://$GCS_BUCKET > /dev/null 2>&1; then
    gcloud storage rm -r gs://$GCS_BUCKET
    echo "[$(date)] ==================== GCS bucket deleted. ===================="
else
    echo "[$(date)] ==================== GCS bucket did not exist (Skipping). ===================="
fi

gcloud iam service-accounts delete $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID --quiet || true
echo "[$(date)] ==================== Google Service Account deleted. ===================="
# [END hypercomputer_gpu_tune_gemma3_ray_cleanup]
