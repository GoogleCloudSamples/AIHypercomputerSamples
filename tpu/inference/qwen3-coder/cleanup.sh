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

if [[ "${ACCELERATOR_TYPE:-v7x}" == "v6e" ]]; then
# [START hypercomputer_tpu_infer_qwen3_coder_cleanup_workload_v6e]
kubectl delete -f qwen3-coder-30b-multihost-disagg-v6e-2x4.yaml --ignore-not-found
# [END hypercomputer_tpu_infer_qwen3_coder_cleanup_workload_v6e]
elif [[ "${ACCELERATOR_TYPE:-v7x}" == "v7x" ]]; then
# [START hypercomputer_tpu_infer_qwen3_coder_cleanup_workload]
kubectl delete -f qwen3-coder-480b-multihost-disagg-v7x.yaml --ignore-not-found
# [END hypercomputer_tpu_infer_qwen3_coder_cleanup_workload]
else
  echo "Unsupported ACCELERATOR_TYPE: ${ACCELERATOR_TYPE}"
  exit 1
fi

echo "Waiting for any running GKE cluster operations to finish..."
while gcloud container operations list --project="${PROJECT_ID}" --location="${REGION}" --filter="status=RUNNING AND targetLink:${CLUSTER_NAME}" --format="value(name)" 2>/dev/null | grep -q .; do
  sleep 10
done

if [[ "${ACCELERATOR_TYPE:-v7x}" == "v6e" ]]; then
# [START hypercomputer_tpu_infer_qwen3_coder_cleanup_cluster_v6e]
gcloud container node-pools delete tpu-v6e-pool-0 \
    --cluster=${CLUSTER_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet

gcloud container node-pools delete tpu-v6e-pool-1 \
    --cluster=${CLUSTER_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet

gcloud container clusters delete ${CLUSTER_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet
# [END hypercomputer_tpu_infer_qwen3_coder_cleanup_cluster_v6e]
elif [[ "${ACCELERATOR_TYPE:-v7x}" == "v7x" ]]; then
# [START hypercomputer_tpu_infer_qwen3_coder_cleanup_cluster]
gcloud container node-pools delete tpu7x-pool-0 \
    --cluster=${CLUSTER_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet

gcloud container node-pools delete tpu7x-pool-1 \
    --cluster=${CLUSTER_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet

gcloud container clusters delete ${CLUSTER_NAME} \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet

gcloud compute resource-policies delete tpu7x-2x2x2-workload-policy \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --quiet
# [END hypercomputer_tpu_infer_qwen3_coder_cleanup_cluster]
fi
