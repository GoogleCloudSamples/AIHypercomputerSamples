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

# [START hypercomputer_tpu_infer_qwen3_coder_create_cluster]
gcloud container clusters create $CLUSTER_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --machine-type=e2-standard-4

gcloud compute resource-policies create workload-policy tpu7x-2x2x2-workload-policy \
    --type=HIGH_THROUGHPUT \
    --accelerator-topology=2x2x2 \
    --project=${PROJECT_ID} \
    --region=${REGION}

gcloud container node-pools create tpu7x-pool-0 \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --node-locations=$ZONE \
    --machine-type=tpu7x-standard-4t \
    --num-nodes=2 \
    --placement-policy=tpu7x-2x2x2-workload-policy \
    --reservation-affinity=specific \
    --reservation=$RESERVATION \
    --project=$PROJECT_ID

gcloud container node-pools create tpu7x-pool-1 \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --node-locations=$ZONE \
    --machine-type=tpu7x-standard-4t \
    --num-nodes=2 \
    --placement-policy=tpu7x-2x2x2-workload-policy \
    --reservation-affinity=specific \
    --reservation=$RESERVATION \
    --project=$PROJECT_ID

gcloud container clusters get-credentials $CLUSTER_NAME --location=${REGION} --project=${PROJECT_ID}
# [END hypercomputer_tpu_infer_qwen3_coder_create_cluster]

# [START hypercomputer_tpu_infer_qwen3_coder_setup_workload]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HF_TOKEN}

kubectl apply --server-side -k github.com/kubernetes-sigs/lws/config/default?ref=main
# [END hypercomputer_tpu_infer_qwen3_coder_setup_workload]

kubectl wait --for=condition=Available --timeout=300s deployment/lws-controller-manager -n lws-system
