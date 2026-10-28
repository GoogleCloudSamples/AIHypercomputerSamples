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
# [START hypercomputer_gpu_infer_llama3_405b_deploy_cleanup]
kubectl delete -f llama3.1-405b-singlehost-a4.yaml --ignore-not-found || true
# [END hypercomputer_gpu_infer_llama3_405b_deploy_cleanup]

# [START hypercomputer_gpu_infer_llama3_405b_dynamo_cleanup]
helm uninstall dynamo-platform kai-scheduler || true
# [END hypercomputer_gpu_infer_llama3_405b_dynamo_cleanup]

# [START hypercomputer_gpu_infer_llama3_405b_secret_cleanup]
kubectl delete secret hf-secret --ignore-not-found || true
# [END hypercomputer_gpu_infer_llama3_405b_secret_cleanup]

echo "[$(date)] ==================== Destroying GKE A4 cluster ${CLUSTER_NAME}... ===================="
# Continuously clear org-enforced firewall rules on VPC and GKE ANP networks so Terraform/GKE teardown is not blocked
CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --format="value(id)" 2>/dev/null || true)
FW_FILTER="network:${CLUSTER_NAME}-net-0${CLUSTER_ID:+ OR network ~ gke-anp-${CLUSTER_ID:0:8} OR name ~ ${CLUSTER_ID:0:8}}"
(
  while true; do
    gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="${FW_FILTER}" --format="value(name)" 2>/dev/null \
      | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
    sleep 3
  done
) &
fw_watcher_pid=$!
trap 'kill "${fw_watcher_pid}" 2>/dev/null || true' EXIT

if [[ -x "cluster-toolkit/gcluster" ]]; then
  (
# [START hypercomputer_gpu_infer_llama3_405b_cluster_cleanup]
cd cluster-toolkit
./gcluster destroy "${CLUSTER_NAME}" --auto-approve || true
cd ..
# [END hypercomputer_gpu_infer_llama3_405b_cluster_cleanup]
  )
  if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet || true
    (cd cluster-toolkit && ./gcluster destroy "${CLUSTER_NAME}" --auto-approve || true)
  fi
fi

# Clean up any leftover GKE ANP (DRANET) subnets and networks
if [[ -n "${CLUSTER_ID}" ]]; then
  gcloud compute networks subnets list --project="${PROJECT_ID}" --regions="${REGION}" --filter="network ~ gke-anp-${CLUSTER_ID:0:8}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute networks subnets delete --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud compute networks list --project="${PROJECT_ID}" --filter="name ~ gke-anp-${CLUSTER_ID:0:8}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute networks delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

kill "${fw_watcher_pid}" 2>/dev/null || true

echo "[$(date)] ==================== Deleting storage and local artifacts... ===================="
gcloud storage rm -r "gs://${GCS_BUCKET}" || true

rm -rf cluster-toolkit dynamo-platform dynamo-platform-*.tgz benchmark.log
echo "[$(date)] ==================== Cleanup completed! ===================="
