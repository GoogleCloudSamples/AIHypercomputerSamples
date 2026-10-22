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

set -uo pipefail

echo "[$(date)] ==================== Deleting Kubernetes workloads, Helm releases, and secrets... ===================="
# [START hypercomputer_gpu_infer_qwen38_2t_deploy_cleanup]
kubectl delete -f qwen3.8-2.4t-nvfp4-multihost-a4.yaml --ignore-not-found || true
helm uninstall dynamo-platform kai-scheduler 2>/dev/null || true
kubectl delete secret hf-secret --ignore-not-found || true
# [END hypercomputer_gpu_infer_qwen38_2t_deploy_cleanup]

echo "[$(date)] ==================== Discovering Cluster Metadata ===================="
CLUSTER_HASH=""
for loc in "${ZONE}" "${REGION}"; do
  CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${loc}" --project="${PROJECT_ID}" --format="value(id)" 2>/dev/null || true)
  if [[ -n "${CLUSTER_ID}" ]]; then
    CLUSTER_HASH="${CLUSTER_ID:0:8}"
    break
  fi
done

cleanup_extra_firewalls() {
  local filter="network:${CLUSTER_NAME}-net-0"
  if [[ -n "${CLUSTER_HASH}" ]]; then
    filter="${filter} OR network ~ gke-anp-${CLUSTER_HASH} OR name ~ ${CLUSTER_HASH}"
  fi
  local rules
  rules=$(gcloud compute firewall-rules list --project="${PROJECT_ID}" \
    --filter="${filter}" \
    --format="value(name)" 2>/dev/null || true)
  if [[ -n "${rules}" ]]; then
    echo "Deleting VPC/ANP firewall rules for ${CLUSTER_NAME}..."
    echo "${rules}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  fi
}

cleanup_extra_firewalls

echo "[$(date)] ==================== Destroying GKE A4 cluster ${CLUSTER_NAME}... ===================="
if [[ -x "cluster-toolkit/gcluster" ]]; then
  (
    cd cluster-toolkit
# [START hypercomputer_gpu_infer_qwen38_2t_cluster_cleanup]
./gcluster destroy "${CLUSTER_NAME}" --auto-approve || true
# [END hypercomputer_gpu_infer_qwen38_2t_cluster_cleanup]
  )
fi

for loc in "${ZONE}" "${REGION}"; do
  if gcloud container clusters describe "${CLUSTER_NAME}" --location="${loc}" --project="${PROJECT_ID}" &>/dev/null; then
    echo "Cluster still exists in ${loc} after gcluster destroy. Cleaning up firewall rules and force deleting via gcloud..."
    cleanup_extra_firewalls
    gcloud container clusters delete "${CLUSTER_NAME}" --location="${loc}" --project="${PROJECT_ID}" --quiet || true
  fi
done

if [[ -n "${CLUSTER_HASH}" ]]; then
  cleanup_extra_firewalls
  anp_nets=$(gcloud compute networks list --project="${PROJECT_ID}" \
    --filter="name ~ gke-anp-${CLUSTER_HASH}" \
    --format="value(name)" 2>/dev/null || true)
  if [[ -n "${anp_nets}" ]]; then
    echo "Cleaning up dangling ANP networks for cluster hash ${CLUSTER_HASH}..."
    echo "${anp_nets}" | xargs -r gcloud compute networks delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  fi
fi

if gcloud compute routers describe "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  gcloud compute routers nats delete "cloud-nat-${REGION}" --router="${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud compute routers delete "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

if gcloud compute networks subnets describe "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  for _ in 1 2 3; do
    gcloud compute networks subnets delete "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null && break || sleep 5
  done
fi

ips=$(gcloud compute addresses list --project="${PROJECT_ID}" --filter="name ~ ${CLUSTER_NAME}-net-0-nat-ips" --format="value(name)" --regions="${REGION}" 2>/dev/null || true)
if [[ -n "${ips}" ]]; then
  echo "${ips}" | xargs -r gcloud compute addresses delete --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

for _ in 1 2 3; do
  if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" &>/dev/null; then
    cleanup_extra_firewalls
    gcloud compute networks delete "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" --quiet 2>/dev/null && break || sleep 5
  else
    break
  fi
done

for sa_prefix in gke-wl-sa gke-np-sa; do
  SA_EMAIL="${CLUSTER_NAME}-${sa_prefix}@${PROJECT_ID}.iam.gserviceaccount.com"
  if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" &>/dev/null; then
    gcloud iam service-accounts delete "${SA_EMAIL}" --project="${PROJECT_ID}" --quiet || true
  fi
done

echo "[$(date)] ==================== Deleting storage and local artifacts... ===================="
for bucket in $(gcloud storage buckets list --project="${PROJECT_ID}" --format="value(name)" 2>/dev/null | grep -E "^(training-data|checkpoint-data)-${CLUSTER_NAME}-|^${GCS_BUCKET:-NONE}$" || true); do
  echo "Deleting Cloud Storage bucket gs://${bucket}..."
  gcloud storage rm -r "gs://${bucket}" || echo "Warning: Failed to delete bucket gs://${bucket}"
done

rm -rf cluster-toolkit dynamo-platform dynamo-platform-*.tgz benchmark.log
echo "[$(date)] ==================== Cleanup completed! ===================="
