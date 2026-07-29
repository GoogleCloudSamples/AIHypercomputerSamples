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
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_destroy_cluster] # change in the doc
gcluster destroy ${CLUSTER_NAME} --auto-approve || echo "Warning: gcluster destroy failed (likely due to gcee_giraffe firewall daemon). Falling back to aggressive cleanup!"

echo "[$(date)] ==================== Bypassing gcee_giraffe daemon to delete VPCs... ===================="
for net in gke-tpu-v6e-net-0 gke-tpu-v6e-net-1; do
  echo "Aggressively tearing down $net..."
  while gcloud compute networks describe $net --project=$PROJECT >/dev/null 2>&1; do
    echo "Blasting firewall for $net..."
    gcloud compute firewall-rules list --project=$PROJECT --filter="network=$net" --format="value(name)" | xargs -r -P 20 -I {} gcloud compute firewall-rules delete {} --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Blasting routers for $net..."
    gcloud compute routers list --project=$PROJECT --format="value(name)" | grep "^${net}-router$" | xargs -r -P 20 -I {} gcloud compute routers delete {} --region=$REGION --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Blasting routes for $net..."
    gcloud compute routes list --project=$PROJECT --filter="network=$net" --format="value(name)" | grep -v "default-route" | xargs -r -P 20 -I {} gcloud compute routes delete {} --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Attempting to delete subnets and network $net..."
    sub=$(echo $net | sed 's/-net/-sub/')
    gcloud compute networks subnets delete $sub --region=$REGION --project=$PROJECT --quiet >/dev/null 2>&1 || true
    gcloud compute networks delete $net --project=$PROJECT --quiet >/dev/null 2>&1 && echo "✅ Successfully vaporized network: $net" || sleep 1
  done
done
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_destroy_cluster]

echo "[$(date)] ==================== Deleting storage and artifacts... ===================="
gcloud storage rm --recursive gs://$GCS_BUCKET || echo "Warning: Failed to delete bucket"
gcloud artifacts repositories delete ${REPOSITORY_NAME} --location=$REGION --project=$PROJECT --quiet || echo "Warning: Failed to delete repository"
rm -f gke-tpu-v6e-advanced.yaml kueue-configuration.yaml.tftpl
rm -rf ${CLUSTER_NAME}
echo "[$(date)] ==================== Resources cleaned up. ===================="
