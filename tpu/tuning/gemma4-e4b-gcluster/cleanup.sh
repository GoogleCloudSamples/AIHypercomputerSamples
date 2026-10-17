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

echo "[$(date)] ==================== Cleaning up resources... ===================="
echo "Waiting for background cluster operations (like autoscaling) to finish..."
while gcloud container operations list --project=$PROJECT --location=$REGION --filter="status=RUNNING AND targetLink:$CLUSTER_NAME" --format="value(name)" | grep -q .; do
  sleep 30
done

echo "[$(date)] ==================== Destroying Cluster... ===================="
gcluster destroy ${CLUSTER_NAME} --auto-approve --robust || echo "Warning: gcluster destroy failed. Falling back to aggressive cleanup!"

echo "[$(date)] ==================== Bypassing gcee_giraffe daemon to delete VPCs... ===================="
echo "Forcefully ensuring GKE cluster is deleted first..."
gcloud container clusters delete ${CLUSTER_NAME} --region=$REGION --project=$PROJECT --quiet || true
for net in ${CLUSTER_NAME}-net-0 ${CLUSTER_NAME}-net-1 gke-tpu-v6e-net-0 gke-tpu-v6e-net-1; do
  echo "Aggressively tearing down $net..."
  count=0
  while gcloud compute networks describe $net --project=$PROJECT >/dev/null 2>&1; do
    if [ $count -ge 30 ]; then
      echo "Warning: Could not delete network $net after 30 attempts."
      break
    fi
    echo "Blasting firewall for $net..."
    gcloud compute firewall-rules list --project=$PROJECT --filter="network:$net" --format="value(name)" | xargs -r -P 20 -I {} gcloud compute firewall-rules delete {} --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Blasting routers for $net..."
    gcloud compute routers list --project=$PROJECT --filter="network:$net" --format="value(name)" | xargs -r -P 20 -I {} gcloud compute routers delete {} --region=$REGION --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Blasting static NAT IPs for $net..."
    gcloud compute addresses delete ${net}-nat-ips-${REGION}-0 --region=$REGION --project=$PROJECT --quiet >/dev/null 2>&1 || true
    gcloud compute addresses delete ${net}-nat-ips-${REGION}-1 --region=$REGION --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Blasting routes for $net..."
    gcloud compute routes list --project=$PROJECT --filter="network:$net" --format="value(name)" | grep -v "default-route" | xargs -r -P 20 -I {} gcloud compute routes delete {} --project=$PROJECT --quiet >/dev/null 2>&1 || true

    echo "Attempting to delete subnets and network $net..."
    gcloud compute networks subnets list --project=$PROJECT --filter="network:$net" --format="value(name)" | xargs -r -P 20 -I {} gcloud compute networks subnets delete {} --region=$REGION --project=$PROJECT --quiet >/dev/null 2>&1 || true
    gcloud compute networks delete $net --project=$PROJECT --quiet >/dev/null 2>&1 && echo "✅ Successfully vaporized network: $net" || sleep 2
    count=$((count+1))
  done
done

echo "Cleaning up orphaned Service Accounts..."
gcloud iam service-accounts delete ${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com --project=$PROJECT --quiet >/dev/null 2>&1 || true
gcloud iam service-accounts delete ${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com --project=$PROJECT --quiet >/dev/null 2>&1 || true

echo "[$(date)] ==================== Deleting storage and artifacts... ===================="
gcloud storage rm -r gs://$GCS_BUCKET || echo "Warning: Failed to delete bucket"
gcloud artifacts repositories delete ${REPOSITORY_NAME} --location=$REGION --project=$PROJECT --quiet || echo "Warning: Failed to delete repository"
rm -f gke-tpu-v6e-advanced.yaml kueue-configuration.yaml.tftpl
rm -rf .ghpc
rm -rf ${CLUSTER_NAME}
echo "[$(date)] ==================== Resources cleaned up. ===================="
