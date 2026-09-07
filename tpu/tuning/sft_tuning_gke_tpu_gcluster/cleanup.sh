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

echo "[$(date)] ==================== Destroying Cluster... ===================="
if [[ -d "${CLUSTER_NAME}" ]]; then
  ./gcluster destroy "${CLUSTER_NAME}" --auto-approve || true
fi

# Fallback: Check if GKE cluster still exists and delete it
if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" >/dev/null 2>&1; then
  echo "Fallback: Deleting GKE cluster ${CLUSTER_NAME} via gcloud..."
  gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" --quiet || true
fi

# Clean up firewall rules for the cluster network if any remain
FW_RULES=$(gcloud compute firewall-rules list --project="${PROJECT}" --filter="network:${CLUSTER_NAME}-net-0" --format="value(name)" 2>/dev/null || true)
if [[ -n "${FW_RULES}" ]]; then
  echo "Deleting dangling firewall rules on network ${CLUSTER_NAME}-net-0..."
  echo "${FW_RULES}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT}" --quiet || true
fi

# Clean up VPC network and subnets if left behind
if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project="${PROJECT}" >/dev/null 2>&1; then
  echo "Fallback: Deleting VPC subnets and network ${CLUSTER_NAME}-net-0..."
  SUBNETS=$(gcloud compute networks subnets list --network="${CLUSTER_NAME}-net-0" --project="${PROJECT}" --format="value(name,region)" 2>/dev/null || true)
  while read -r sub_name sub_region; do
    if [[ -n "${sub_name}" && -n "${sub_region}" ]]; then
      gcloud compute networks subnets delete "${sub_name}" --region="${sub_region}" --project="${PROJECT}" --quiet || true
    fi
  done <<< "${SUBNETS}"
  gcloud compute networks delete "${CLUSTER_NAME}-net-0" --project="${PROJECT}" --quiet || true
fi

echo "[$(date)] ==================== Deleting storage and artifacts... ===================="
if gcloud storage buckets describe "gs://${GCS_BUCKET}" --project="${PROJECT}" >/dev/null 2>&1; then
  echo "Deleting Cloud Storage bucket gs://${GCS_BUCKET}..."
  gcloud storage rm -r "gs://${GCS_BUCKET}" || echo "Warning: Failed to delete bucket"
fi

if gcloud artifacts repositories describe "${REPOSITORY_NAME}" --location="${REGION}" --project="${PROJECT}" >/dev/null 2>&1; then
  echo "Deleting Artifact Registry repository ${REPOSITORY_NAME}..."
  gcloud artifacts repositories delete "${REPOSITORY_NAME}" --location="${REGION}" --project="${PROJECT}" --quiet || echo "Warning: Failed to delete repository"
fi

rm -rf .ghpc "${CLUSTER_NAME}" gcluster examples community gcluster_bundle_linux_amd64.tgz
echo "[$(date)] ==================== Resources cleaned up. ===================="
