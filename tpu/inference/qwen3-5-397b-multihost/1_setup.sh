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

echo "[$(date)] ==================== Creating GKE Standard cluster ${CLUSTER_NAME}... ===================="
if ! gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_create]
  gcloud container clusters create "${CLUSTER_NAME}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --machine-type="e2-standard-4" \
      --workload-pool="${PROJECT_ID}.svc.id.goog"
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_create]
else
  echo "Cluster ${CLUSTER_NAME} already exists."
fi

echo "Verifying cluster status..."
STATUS=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --format="value(status)")

if [[ "${STATUS}" == "RUNNING" ]]; then
  echo "[$(date)] Cluster ${CLUSTER_NAME} is RUNNING and ready for node pool creation."
else
  echo "[$(date)] Warning: Cluster is in '${STATUS}' state." >&2
  exit 1
fi

echo "[$(date)] ==================== Creating workload policy ${WORKLOAD_POLICY_NAME}... ===================="
if ! gcloud compute resource-policies describe "${WORKLOAD_POLICY_NAME}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_workload_policy_create]
  gcloud compute resource-policies create workload-policy "${WORKLOAD_POLICY_NAME}" \
      --type=HIGH_THROUGHPUT \
      --accelerator-topology=2x2x2 \
      --project="${PROJECT_ID}" \
      --region="${REGION}"
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_workload_policy_create]
else
  echo "Workload policy ${WORKLOAD_POLICY_NAME} already exists."
fi

if [[ ( "${USE_FLEX_START:-false}" == "true" || -z "${RESERVATION_NAME:-}" || "${RESERVATION_NAME}" == "YOUR_RESERVATION_NAME" ) && "${USE_SPOT:-false}" != "true" ]]; then
  echo "[$(date)] ==================== Creating TPU v7x node pools ${NODE_POOL_NAME_0} and ${NODE_POOL_NAME_1} (Flex-Start)... ===================="
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_flex_start]
  gcloud container node-pools create "${NODE_POOL_NAME_0}" \
      --cluster="${CLUSTER_NAME}" \
      --machine-type="${MACHINE_TYPE}" \
      --placement-policy="${WORKLOAD_POLICY_NAME}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --project="${PROJECT_ID}" \
      --reservation-affinity=none \
      --enable-autoscaling \
      --num-nodes=0 \
      --min-nodes=0 \
      --max-nodes=2 \
      --flex-start

  gcloud container node-pools create "${NODE_POOL_NAME_1}" \
      --cluster="${CLUSTER_NAME}" \
      --machine-type="${MACHINE_TYPE}" \
      --placement-policy="${WORKLOAD_POLICY_NAME}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --project="${PROJECT_ID}" \
      --reservation-affinity=none \
      --enable-autoscaling \
      --num-nodes=0 \
      --min-nodes=0 \
      --max-nodes=2 \
      --flex-start
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_flex_start]
elif [[ "${USE_SPOT:-false}" == "true" ]]; then
  echo "[$(date)] ==================== Creating TPU v7x node pools ${NODE_POOL_NAME_0} and ${NODE_POOL_NAME_1} (Spot VMs)... ===================="
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_spot]
  gcloud container node-pools create "${NODE_POOL_NAME_0}" \
      --cluster="${CLUSTER_NAME}" \
      --machine-type="${MACHINE_TYPE}" \
      --placement-policy="${WORKLOAD_POLICY_NAME}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --project="${PROJECT_ID}" \
      --num-nodes=2 \
      --spot

  gcloud container node-pools create "${NODE_POOL_NAME_1}" \
      --cluster="${CLUSTER_NAME}" \
      --machine-type="${MACHINE_TYPE}" \
      --placement-policy="${WORKLOAD_POLICY_NAME}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --project="${PROJECT_ID}" \
      --num-nodes=2 \
      --spot
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_spot]
else
  echo "[$(date)] ==================== Creating TPU v7x node pools ${NODE_POOL_NAME_0} and ${NODE_POOL_NAME_1} (Reservation: ${RESERVATION_NAME})... ===================="
  # [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_reservation]
  gcloud container node-pools create "${NODE_POOL_NAME_0}" \
      --cluster="${CLUSTER_NAME}" \
      --machine-type="${MACHINE_TYPE}" \
      --placement-policy="${WORKLOAD_POLICY_NAME}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --project="${PROJECT_ID}" \
      --num-nodes=2 \
      --reservation-affinity=specific \
      --reservation="${RESERVATION_NAME}"

  gcloud container node-pools create "${NODE_POOL_NAME_1}" \
      --cluster="${CLUSTER_NAME}" \
      --machine-type="${MACHINE_TYPE}" \
      --placement-policy="${WORKLOAD_POLICY_NAME}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --project="${PROJECT_ID}" \
      --num-nodes=2 \
      --reservation-affinity=specific \
      --reservation="${RESERVATION_NAME}"
  # [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_reservation]
fi

echo "[$(date)] ==================== Getting cluster credentials... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_cluster_get_creds]

echo "[$(date)] ==================== Creating hf-secret secret... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_secret_create]

echo "[$(date)] ==================== Installing JobSet CRD... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_jobset_install]
kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/v0.12.0/manifests.yaml
kubectl wait --for=condition=Available --timeout=300s deployment/jobset-controller-manager -n jobset-system
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_jobset_install]
