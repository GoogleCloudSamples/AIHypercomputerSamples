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

if [[ -z "${NETWORK:-}" || "${NETWORK}" == "YOUR_NETWORK_NAME" ]]; then
  NETWORK="default"
fi
if [[ -z "${SUBNETWORK:-}" || "${SUBNETWORK}" == "YOUR_SUBNETWORK_NAME" ]]; then
  SUBNETWORK="default"
fi

echo "[$(date)] ==================== Creating GKE Standard cluster ${CLUSTER_NAME}... ===================="
if ! gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  # [START hypercomputer_tpu_infer_qwen3_5_397b_cluster_create]
  gcloud container clusters create "${CLUSTER_NAME}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --node-locations="${ZONE}" \
      --machine-type=e2-standard-4 \
      --network="${NETWORK}" \
      --subnetwork="${SUBNETWORK}"
  # [END hypercomputer_tpu_infer_qwen3_5_397b_cluster_create]
else
  echo "Cluster ${CLUSTER_NAME} already exists."
fi

echo "Verifying cluster status..."
STATUS=$(gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --format="value(status)")

if [[ "${STATUS}" == "RUNNING" ]]; then
  echo "[$(date)] Success! Cluster ${CLUSTER_NAME} is RUNNING and ready for node pool creation."
else
  echo "[$(date)] Warning: Cluster is in '${STATUS}' state." >&2
  exit 1
fi

if ! gcloud container node-pools describe "${NODE_POOL_NAME}" --cluster="${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  if [[ "${USE_SPOT:-false}" == "true" || -z "${RESERVATION_NAME:-}" || "${RESERVATION_NAME}" == "YOUR_RESERVATION_NAME" || "${RESERVATION_NAME}" == "spot" || "${RESERVATION_NAME}" == "none" ]]; then
    echo "[$(date)] ==================== Creating TPU ${TPU_TYPE:-v7x} node pool ${NODE_POOL_NAME} (Spot VMs)... ===================="
    # [START hypercomputer_tpu_infer_qwen3_5_397b_nodepool_create_spot]
    gcloud container node-pools create "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --machine-type="${MACHINE_TYPE}" \
        --location="${REGION}" \
        --node-locations="${ZONE}" \
        --project="${PROJECT_ID}" \
        --num-nodes=1 \
        --spot
    # [END hypercomputer_tpu_infer_qwen3_5_397b_nodepool_create_spot]
  else
    echo "[$(date)] ==================== Creating TPU ${TPU_TYPE:-v7x} node pool ${NODE_POOL_NAME} (Reservation: ${RESERVATION_NAME})... ===================="
    # [START hypercomputer_tpu_infer_qwen3_5_397b_nodepool_create_reservation]
    gcloud container node-pools create "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --machine-type="${MACHINE_TYPE}" \
        --location="${REGION}" \
        --node-locations="${ZONE}" \
        --project="${PROJECT_ID}" \
        --num-nodes=1 \
        --reservation-affinity=specific \
        --reservation="${RESERVATION_NAME}"
    # [END hypercomputer_tpu_infer_qwen3_5_397b_nodepool_create_reservation]
  fi
else
  echo "Node pool ${NODE_POOL_NAME} already exists."
fi

echo "[$(date)] ==================== Getting cluster credentials... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}"
# [END hypercomputer_tpu_infer_qwen3_5_397b_cluster_get_creds]

echo "[$(date)] ==================== Creating hf-secret secret... ===================="
# [START hypercomputer_tpu_infer_qwen3_5_397b_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_tpu_infer_qwen3_5_397b_secret_create]
