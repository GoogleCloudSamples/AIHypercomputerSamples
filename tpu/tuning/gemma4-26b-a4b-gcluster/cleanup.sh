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
for loc in "${ZONE}" "${REGION}"; do
  CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${loc}" --project="${PROJECT}" --format="value(id)" 2>/dev/null || true)
  if [ -n "${CLUSTER_ID}" ]; then
    CLUSTER_HASH="${CLUSTER_ID:0:8}"
    break
  fi
done

if [ -z "${CLUSTER_HASH}" ] && [ -f "${CLUSTER_NAME}/primary/terraform.tfstate" ]; then
  CLUSTER_HASH=$(grep -o 'gke-anp-[a-f0-9]\{8\}' "${CLUSTER_NAME}/primary/terraform.tfstate" 2>/dev/null | head -1 | cut -d'-' -f3 || true)
fi

cleanup_extra_firewalls() {
  local filter="network:${CLUSTER_NAME}-net-0"
  if [ -n "${CLUSTER_HASH}" ]; then
    filter="${filter} OR network ~ gke-anp-${CLUSTER_HASH} OR name ~ ${CLUSTER_HASH}"
  fi
  local rules
  rules=$(gcloud compute firewall-rules list --project="${PROJECT}" \
    --filter="${filter}" \
    --format="value(name)" 2>/dev/null || true)
  if [ -n "${rules}" ]; then
    echo "Deleting VPC/ANP firewall rules (including org-enforced rules) for ${CLUSTER_NAME}..."
    echo "${rules}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT}" --quiet 2>/dev/null || true
  fi
}

# Pre-emptively clean up VPC/ANP firewall rules (including gceenforcer-enforcer rules outside Terraform state)
cleanup_extra_firewalls

echo "[$(date)] ==================== Destroying Cluster... ===================="
./gcluster destroy ${CLUSTER_NAME} --auto-approve || true

# Fallback: force delete GKE cluster via gcloud if gcluster/Terraform failed to destroy it
for loc in "${ZONE}" "${REGION}"; do
  if gcloud container clusters describe "${CLUSTER_NAME}" --location="${loc}" --project="${PROJECT}" &>/dev/null; then
    echo "Cluster still exists in ${loc} after gcluster destroy. Cleaning up firewall rules and force deleting GKE cluster via gcloud..."
    cleanup_extra_firewalls
    gcloud container clusters delete "${CLUSTER_NAME}" --location="${loc}" --project="${PROJECT}" --quiet || true
  fi
done

# Fallback: clean up any remaining ANP networks for this cluster hash
if [ -n "${CLUSTER_HASH}" ]; then
  cleanup_extra_firewalls
  anp_nets=$(gcloud compute networks list --project="${PROJECT}" \
    --filter="name ~ gke-anp-${CLUSTER_HASH}" \
    --format="value(name)" 2>/dev/null || true)
  if [ -n "${anp_nets}" ]; then
    echo "Cleaning up dangling ANP networks for cluster hash ${CLUSTER_HASH}..."
    echo "${anp_nets}" | xargs -r gcloud compute networks delete --project="${PROJECT}" --quiet 2>/dev/null || true
  fi
fi

# Fallback: clean up dangling router, NAT, subnet, and VPC network if left behind
if gcloud compute routers describe "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT}" &>/dev/null; then
  echo "Cleaning up dangling router and NAT..."
  gcloud compute routers nats delete "cloud-nat-${REGION}" --router="${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT}" --quiet 2>/dev/null || true
  gcloud compute routers delete "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT}" --quiet 2>/dev/null || true
fi

if gcloud compute networks subnets describe "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT}" &>/dev/null; then
  echo "Cleaning up dangling subnet..."
  for _ in 1 2 3; do
    gcloud compute networks subnets delete "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT}" --quiet 2>/dev/null && break || sleep 5
  done
fi

# Fallback: clean up dangling NAT static IP addresses
ips=$(gcloud compute addresses list --project="${PROJECT}" --filter="name ~ ${CLUSTER_NAME}-net-0-nat-ips" --format="value(name)" --regions="${REGION}" 2>/dev/null || true)
if [ -n "$ips" ]; then
  echo "Deleting dangling NAT IP addresses..."
  echo "$ips" | xargs -r gcloud compute addresses delete --region="${REGION}" --project="${PROJECT}" --quiet 2>/dev/null || true
fi

for _ in 1 2 3; do
  if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project="${PROJECT}" &>/dev/null; then
    echo "Cleaning up dangling firewall rules and VPC network..."
    cleanup_extra_firewalls
    gcloud compute networks delete "${CLUSTER_NAME}-net-0" --project="${PROJECT}" --quiet 2>/dev/null && break || sleep 5
  else
    break
  fi
done

echo "[$(date)] ==================== Cleaning up dangling Service Accounts... ===================="
WL_SA="${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "${WL_SA}" --project="${PROJECT}" &>/dev/null; then
  echo "Deleting dangling workload service account ${WL_SA}..."
  gcloud iam service-accounts delete "${WL_SA}" --project="${PROJECT}" --quiet || true
fi

NP_SA="${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "${NP_SA}" --project="${PROJECT}" &>/dev/null; then
  echo "Deleting dangling node pool service account ${NP_SA}..."
  gcloud iam service-accounts delete "${NP_SA}" --project="${PROJECT}" --quiet || true
fi

echo "[$(date)] ==================== Deleting storage and artifacts... ===================="
for bucket in $(gcloud storage buckets list --project="${PROJECT}" --format="value(name)" 2>/dev/null | grep -E "^(training-data|checkpoint-data)-${CLUSTER_NAME}-|^${GCS_BUCKET:-NONE}$" || true); do
  echo "Deleting Cloud Storage bucket gs://${bucket}..."
  gcloud storage rm -r "gs://${bucket}" || echo "Warning: Failed to delete bucket gs://${bucket}"
done

rm -rf .ghpc "${CLUSTER_NAME}" gcluster examples community gcluster_bundle_linux_amd64.tgz
echo "[$(date)] ==================== Resources cleaned up. ===================="
