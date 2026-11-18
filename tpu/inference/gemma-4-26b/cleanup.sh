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

# [START hypercomputer_tpu_infer_gemma4_26b_deploy_cleanup]
envsubst '$RESERVATION_NAME $ZONE $VLLM_IMAGE' < gemma4-26b-multihost-v6e-2x4.yaml | kubectl delete -f - --ignore-not-found || true
kubectl delete secret hf-secret --ignore-not-found || true
# [END hypercomputer_tpu_infer_gemma4_26b_deploy_cleanup]

# [START hypercomputer_tpu_infer_gemma4_26b_cluster_cleanup]
gcloud container node-pools delete "${NODE_POOL_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet || true

# [START_EXCLUDE silent]
# GKE may start internal operations (e.g. RESIZE_CLUSTER) after the node pool
# is deleted. Deleting the cluster while such an operation is running fails
# with "Cluster is running incompatible operation". Wait for them to finish.
echo "Waiting for in-progress GKE operations on ${CLUSTER_NAME} to finish..."
for attempt in $(seq 1 80); do
  ACTIVE_OPS=$(gcloud container operations list \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --filter="status!=DONE AND targetLink~/clusters/${CLUSTER_NAME}(/|$)" \
      --format="value(name)" 2>/dev/null || true)
  if [ -z "${ACTIVE_OPS}" ]; then
    echo "No active GKE operations on ${CLUSTER_NAME}."
    break
  fi
  echo "  Active operation(s): ${ACTIVE_OPS//$'\n'/, } (attempt ${attempt}/80), waiting 15s..."
  sleep 15
done
# [END_EXCLUDE]

gcloud container clusters delete "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet
# [END hypercomputer_tpu_infer_gemma4_26b_cluster_cleanup]