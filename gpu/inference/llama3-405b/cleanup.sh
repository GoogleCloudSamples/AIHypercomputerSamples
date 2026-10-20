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
if [[ -x "cluster-toolkit/gcluster" ]]; then
  (
    cd cluster-toolkit
# [START hypercomputer_gpu_infer_llama3_405b_cluster_cleanup]
./gcluster destroy "${CLUSTER_NAME}" --auto-approve || true
# [END hypercomputer_gpu_infer_llama3_405b_cluster_cleanup]
  )
fi

echo "[$(date)] ==================== Deleting storage and local artifacts... ===================="
gcloud storage rm -r "gs://${GCS_BUCKET}" || true

rm -rf cluster-toolkit dynamo-platform dynamo-platform-*.tgz benchmark.log
echo "[$(date)] ==================== Cleanup completed! ===================="
