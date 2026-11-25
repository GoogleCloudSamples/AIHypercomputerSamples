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

echo "[$(date)] ==================== Deleting jobs and Kueue queues... ===================="
if gcloud container clusters get-credentials "$CLUSTER_NAME" --location "$REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
  # [START hypercomputer_tpu_train_muse_glimmer_30b_delete_jobs]
  kubectl delete jobset --all
  kubectl delete localqueue --all
  kubectl delete clusterqueue,resourceflavor --all
  # [END hypercomputer_tpu_train_muse_glimmer_30b_delete_jobs]
else
  echo "Cluster ${CLUSTER_NAME} not reachable. Skipping Kubernetes resource deletion."
fi

echo "[$(date)] ==================== Discovering cluster metadata... ===================="
# Discover the unique cluster hash to target cluster-specific ANP resources.
CLUSTER_HASH=""
CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --format="value(id)" 2>/dev/null || true)
if [ -n "${CLUSTER_ID}" ]; then
  CLUSTER_HASH="${CLUSTER_ID:0:8}"
fi

cleanup_anp_firewalls() {
  if [ -n "${CLUSTER_HASH}" ]; then
    local rules
    rules=$(gcloud compute firewall-rules list --project="${PROJECT_ID}" \
      --filter="network ~ gke-anp-${CLUSTER_HASH} OR name ~ ${CLUSTER_HASH}" \
      --format="value(name)" 2>/dev/null || true)
    if [ -n "${rules}" ]; then
      echo "Deleting ANP and cluster firewall rules for ${CLUSTER_HASH}..."
      echo "${rules}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
    fi
  fi
}

cleanup_anp_firewalls

echo "[$(date)] ==================== Destroying the cluster... ===================="
if [ -x ./gcluster ] && [ -d "${CLUSTER_NAME}" ]; then
  # [START hypercomputer_tpu_train_muse_glimmer_30b_destroy_cluster]
  ./gcluster destroy "$CLUSTER_NAME" --auto-approve
  # [END hypercomputer_tpu_train_muse_glimmer_30b_destroy_cluster]
else
  echo "Cluster Toolkit binary or deployment directory not found. Skipping gcluster destroy."
fi

# Fallback: force delete the GKE cluster if gcluster or Terraform failed to destroy it.
if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "Cluster still exists after gcluster destroy. Force deleting the GKE cluster..."
  cleanup_anp_firewalls
  gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet || true
fi

# Fallback: clean up remaining ANP networks for this cluster hash.
if [ -n "${CLUSTER_HASH}" ]; then
  cleanup_anp_firewalls
  anp_nets=$(gcloud compute networks list --project="${PROJECT_ID}" \
    --filter="name ~ gke-anp-${CLUSTER_HASH}" \
    --format="value(name)" 2>/dev/null || true)
  if [ -n "${anp_nets}" ]; then
    echo "Cleaning up dangling ANP networks for cluster hash ${CLUSTER_HASH}..."
    echo "${anp_nets}" | xargs -r gcloud compute networks delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  fi
fi

# Fallback: clean up a dangling router, NAT, subnet, NAT IP addresses, and VPC network.
if gcloud compute routers describe "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "Cleaning up dangling router and NAT..."
  gcloud compute routers nats delete "cloud-nat-${REGION}" --router="${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud compute routers delete "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

if gcloud compute networks subnets describe "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "Cleaning up dangling subnet..."
  gcloud compute networks subnets delete "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

ips=$(gcloud compute addresses list --project="${PROJECT_ID}" --filter="name ~ ${CLUSTER_NAME}-net-0-nat-ips" --format="value(name)" --regions="${REGION}" 2>/dev/null || true)
if [ -n "${ips}" ]; then
  echo "Deleting dangling NAT IP addresses..."
  echo "${ips}" | xargs -r gcloud compute addresses delete --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" &>/dev/null; then
  echo "Cleaning up dangling firewall rules and VPC network..."
  fw_rules=$(gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="network:${CLUSTER_NAME}-net-0" --format="value(name)" 2>/dev/null || true)
  if [ -n "${fw_rules}" ]; then
    echo "${fw_rules}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  fi
  gcloud compute networks delete "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

echo "[$(date)] ==================== Deleting buckets and the Artifact Registry repository... ===================="
# The Terraform state bucket is deleted only after the cluster is destroyed.
for bucket in "${BUCKET_NAME:-}" "${TF_STATE_BUCKET:-}"; do
  if [ -n "${bucket}" ] && [[ "${bucket}" != YOUR_* ]] && gcloud storage buckets describe "gs://${bucket}" &>/dev/null; then
    echo "Deleting Cloud Storage bucket gs://${bucket}..."
    gcloud storage rm -r "gs://${bucket}" || echo "Warning: failed to delete gs://${bucket}"
  fi
done

if [ -n "${AR_REPO:-}" ] && [[ "${AR_REPO}" != YOUR_* ]] && gcloud artifacts repositories describe "${AR_REPO}" --location "${REGION}" --project "${PROJECT_ID}" &>/dev/null; then
  echo "Deleting Artifact Registry repository ${AR_REPO}..."
  gcloud artifacts repositories delete "$AR_REPO" --location "$REGION" --project "$PROJECT_ID" --quiet || echo "Warning: failed to delete ${AR_REPO}"
fi

echo "[$(date)] ==================== Removing local files... ===================="
rm -rf .ghpc "${CLUSTER_NAME}" gcluster examples community gcluster_bundle_linux_amd64.tgz \
  torchtitan gke-tpu-v6e.yaml "${CLUSTER_NAME}-deployment.yaml"

echo "[$(date)] ==================== Resources cleaned up. ===================="
