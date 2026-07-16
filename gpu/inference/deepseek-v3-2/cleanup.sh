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

echo "[$(date)] ==================== Deleting the model deployment and hf-secret ===================="
# [START hypercomputer_gpu_infer_deepseek32_deploy_cleanup]
envsubst < vllm-deepseek3-2.yaml | kubectl delete -f -
kubectl delete secret hf-secret
# [END hypercomputer_gpu_infer_deepseek32_deploy_cleanup]

echo "[$(date)] ==================== Deleting the bucket ===================="
# [START hypercomputer_gpu_infer_deepseek32_bucket_cleanup]
gcloud storage rm --recursive gs://$GCS_BUCKET
# [END hypercomputer_gpu_infer_deepseek32_bucket_cleanup]

echo "[$(date)] ==================== Deleting the cluster ===================="
# [START hypercomputer_gpu_infer_deepseek32_cluster_cleanup]
gcloud container clusters delete $CLUSTER_NAME \
    --region=$REGION \
    --quiet
# [END hypercomputer_gpu_infer_deepseek32_cluster_cleanup]
