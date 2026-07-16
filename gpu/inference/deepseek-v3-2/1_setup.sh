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

echo "[$(date)] ==================== Creating Cluster... ===================="
# [START hypercomputer_gpu_infer_deepseek32_cluster_create_auto]
gcloud container clusters create-auto $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --region=$REGION \
    --release-channel=rapid \
    --network=$NETWORK \
    --subnetwork=$SUBNETWORK
# [END hypercomputer_gpu_infer_deepseek32_cluster_create_auto]

echo "Verifying cluster status..."
STATUS=$(gcloud container clusters describe "$CLUSTER_NAME" --region "$REGION" --format="value(status)")

if [ "$STATUS" = "RUNNING" ]; then
    echo "Success! Cluster $CLUSTER_NAME is RUNNING and ready for deployment."
else
    echo "Warning: Cluster is in '$STATUS' state."
    exit 1
fi

# [START hypercomputer_gpu_infer_deepseek32_cluster_get_creds]
gcloud container clusters get-credentials $CLUSTER_NAME \
    --location=$REGION
# [END hypercomputer_gpu_infer_deepseek32_cluster_get_creds]

echo "[$(date)] ==================== Creating hf-secret secret... ===================="
# [START hypercomputer_gpu_infer_deepseek32_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_token=${HUGGING_FACE_TOKEN} \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek32_secret_create]
