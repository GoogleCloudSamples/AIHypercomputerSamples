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


set -uo pipefail

echo "[$(date)] ==================== Discovering Cluster Metadata ===================="
# Discover the unique cluster hash to safely target cluster-specific ANP resources
CLUSTER_HASH=""
CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" --format="value(id)" 2>/dev/null || true)
if [ -n "${CLUSTER_ID}" ]; then
  CLUSTER_HASH="${CLUSTER_ID:0:8}"
fi

if [ -z "${CLUSTER_HASH}" ] && [ -f "${CLUSTER_NAME}/primary/terraform.tfstate" ]; then
  CLUSTER_HASH=$(grep -o 'gke-anp-[a-f0-9]\{8\}' "${CLUSTER_NAME}/primary/terraform.tfstate" 2>/dev/null | head -1 | cut -d'-' -f3 || true)
fi

cleanup_anp_firewalls() {
  if [ -n "${CLUSTER_HASH}" ]; then
    local rules
    rules=$(gcloud compute firewall-rules list --project="${PROJECT}" \
      --filter="network ~ gke-anp-${CLUSTER_HASH} OR name ~ ${CLUSTER_HASH}" \
      --format="value(name)" 2>/dev/null || true)
    if [ -n "${rules}" ]; then
      echo "Deleting ANP and cluster firewall rules for ${CLUSTER_HASH}..."
      echo "${rules}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT}" --quiet 2>/dev/null || true
    fi
  fi
}

# Pre-emptively clean up ANP and cluster firewall rules matching CLUSTER_HASH
cleanup_anp_firewalls

echo "[$(date)] ==================== Destroying Cluster... ===================="
./gcluster destroy ${CLUSTER_NAME} --auto-approve || true

# Fallback: force delete GKE cluster via gcloud if gcluster/Terraform failed to destroy it
if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" &>/dev/null; then
  echo "Cluster still exists after gcluster destroy. Cleaning up firewall rules and force deleting GKE cluster via gcloud..."
  cleanup_anp_firewalls
  gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" --quiet || true
fi

# Fallback: clean up any remaining ANP networks for this cluster hash
if [ -n "${CLUSTER_HASH}" ]; then
  cleanup_anp_firewalls
  anp_nets=$(gcloud compute networks list --project="${PROJECT}" \
    --filter="name ~ gke-anp-${CLUSTER_HASH}" \
    --format="value(name)" 2>/dev/null || true)
  if [ -n "${anp_nets}" ]; then
    echo "Cleaning up dangling ANP networks for cluster hash ${CLUSTER_HASH}..."
    echo "${anp_nets}" | xargs -r gcloud compute networks delete --project="${PROJECT}" --quiet 2>/dev/null || true
  fi
fi

# Fallback: clean up dangling router, NAT, subnet, and VPC network if left behind
if gcloud compute routers describe "${CLUSTER_NAME}-net-0-router" --region=${REGION} --project=${PROJECT} &>/dev/null; then
  echo "Cleaning up dangling router and NAT..."
  gcloud compute routers nats delete "cloud-nat-${REGION}" --router="${CLUSTER_NAME}-net-0-router" --region=${REGION} --project=${PROJECT} --quiet 2>/dev/null || true
  gcloud compute routers delete "${CLUSTER_NAME}-net-0-router" --region=${REGION} --project=${PROJECT} --quiet 2>/dev/null || true
fi

if gcloud compute networks subnets describe "${CLUSTER_NAME}-sub-0" --region=${REGION} --project=${PROJECT} &>/dev/null; then
  echo "Cleaning up dangling subnet..."
  gcloud compute networks subnets delete "${CLUSTER_NAME}-sub-0" --region=${REGION} --project=${PROJECT} --quiet 2>/dev/null || true
fi

if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project=${PROJECT} &>/dev/null; then
  echo "Cleaning up dangling firewall rules and VPC network..."
  fw_rules=$(gcloud compute firewall-rules list --project=${PROJECT} --filter="network:${CLUSTER_NAME}-net-0" --format="value(name)" 2>/dev/null || true)
  if [ -n "$fw_rules" ]; then
    echo "$fw_rules" | xargs -r gcloud compute firewall-rules delete --project=${PROJECT} --quiet 2>/dev/null || true
  fi
  gcloud compute networks delete "${CLUSTER_NAME}-net-0" --project=${PROJECT} --quiet 2>/dev/null || true
fi

echo "[$(date)] ==================== Deleting storage and artifacts... ===================="
if gcloud storage buckets describe "gs://${GCS_BUCKET}" &>/dev/null; then
  echo "Deleting Cloud Storage bucket gs://${GCS_BUCKET}..."
  gcloud storage rm -r "gs://${GCS_BUCKET}" || echo "Warning: Failed to delete bucket"
fi

if gcloud artifacts repositories describe "${REPOSITORY_NAME}" --location="${REGION}" --project="${PROJECT}" &>/dev/null; then
  echo "Deleting Artifact Registry repository ${REPOSITORY_NAME}..."
  gcloud artifacts repositories delete "${REPOSITORY_NAME}" --location="${REGION}" --project="${PROJECT}" --quiet || echo "Warning: Failed to delete repository"
fi

rm -rf .ghpc "${CLUSTER_NAME}" gcluster examples community gcluster_bundle_linux_amd64.tgz
echo "[$(date)] ==================== Resources cleaned up. ===================="