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

kubectl delete deployment vllm-qwen3-deployment || true
kubectl delete job qwen3-model-loader || true
kubectl delete secret hf-secret || true
kubectl delete serviceaccount qwen-ksa || true

gcloud iam service-accounts delete qwen-gcs-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --project=$PROJECT_ID --quiet || true

gcloud storage rm --recursive gs://$GCS_BUCKET_NAME || true

# [START hypercomputer_gpu_infer_qwen3_cluster_cleanup]
gcloud container clusters delete "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
# [END hypercomputer_gpu_infer_qwen3_cluster_cleanup]
