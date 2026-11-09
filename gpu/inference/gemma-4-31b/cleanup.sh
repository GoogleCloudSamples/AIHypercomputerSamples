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

EXISTING_CLUSTERS=$(gcloud container clusters list \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --format="value(name)")
if ! grep -qxF "${CLUSTER_NAME}" <<< "${EXISTING_CLUSTERS}"; then
  echo "Cluster ${CLUSTER_NAME} not found in ${REGION}. Nothing to clean up."
  exit 0
fi

if gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"; then
set +e
# shellcheck disable=SC2016
# [START hypercomputer_gpu_infer_gemma4_31b_deploy_cleanup]
envsubst '$RESERVATION_NAME $VLLM_IMAGE $MODEL_ID' < vllm-gemma-4-31b-it.yaml | kubectl delete -f - --ignore-not-found
kubectl delete secret hf-secret --ignore-not-found
# [END hypercomputer_gpu_infer_gemma4_31b_deploy_cleanup]
set -e
else
  echo "Warning: couldn't get credentials for ${CLUSTER_NAME}; skipping the workload deletion." >&2
fi

echo "Waiting for running GKE operations on ${CLUSTER_NAME} to finish..."
LIMIT=60
count=0
while gcloud container operations list \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --filter="status=RUNNING" \
    --format="value(targetLink)" | grep -E "/clusters/${CLUSTER_NAME}(/|$)" >/dev/null; do
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Warning: GKE operations are still running; trying to delete the cluster anyway." >&2
    break
  fi
  sleep 15
  count=$((count + 1))
done

# [START hypercomputer_gpu_infer_gemma4_31b_cluster_cleanup]
gcloud container clusters delete "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --quiet
# [END hypercomputer_gpu_infer_gemma4_31b_cluster_cleanup]
