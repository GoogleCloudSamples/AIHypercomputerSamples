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

MIN_GKE_VERSION="1.34.0-gke.1662000"

# [START hypercomputer_gpu_infer_gemma4_31b_cluster_create_auto]
gcloud container clusters create-auto "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --release-channel=regular \
    --network="${NETWORK}" \
    --subnetwork="${SUBNETWORK}"
# [END hypercomputer_gpu_infer_gemma4_31b_cluster_create_auto]

echo "Verifying cluster status..."
LIMIT=30
count=0
while true; do
  CLUSTER_INFO=$(gcloud container clusters describe "${CLUSTER_NAME}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --format="value(status,currentMasterVersion)")
  read -r STATUS CLUSTER_VERSION <<< "${CLUSTER_INFO}"
  if [ "${STATUS}" = "RUNNING" ]; then
    break
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: cluster ${CLUSTER_NAME} is in '${STATUS}' state." >&2
    exit 1
  fi
  echo "Cluster is in '${STATUS}' state, waiting..."
  sleep 20
  count=$((count + 1))
done
echo "Cluster ${CLUSTER_NAME} is RUNNING with GKE version ${CLUSTER_VERSION}."

OLDEST_VERSION=$(printf '%s\n' "${MIN_GKE_VERSION}" "${CLUSTER_VERSION}" | sort -V | head -n 1)
if [ "${OLDEST_VERSION}" != "${MIN_GKE_VERSION}" ]; then
  echo "Error: GKE version ${CLUSTER_VERSION} is older than ${MIN_GKE_VERSION}." >&2
  echo "Older versions can install an NVIDIA driver older than R580, which ${VLLM_IMAGE} doesn't support." >&2
  exit 1
fi

# [START hypercomputer_gpu_infer_gemma4_31b_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_gpu_infer_gemma4_31b_cluster_get_creds]

# [START hypercomputer_gpu_infer_gemma4_31b_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HUGGING_FACE_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_gemma4_31b_secret_create]
