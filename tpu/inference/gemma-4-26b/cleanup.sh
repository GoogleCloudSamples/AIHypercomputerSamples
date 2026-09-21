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
envsubst '$RESERVATION_URL $ZONE' < gemma4-26b-multihost-v6e-4x4.yaml | kubectl delete -f - || true
kubectl delete secret hf-secret || true
# [END hypercomputer_tpu_infer_gemma4_26b_deploy_cleanup]

# [START hypercomputer_tpu_infer_gemma4_26b_cluster_cleanup]
gcloud container node-pools delete tpuv6e-pool \
    --cluster=${CLUSTER_NAME} \
    --location=${ZONE} \
    --project=${PROJECT_ID} \
    --quiet || true

gcloud container clusters delete $CLUSTER_NAME \
    --region=$REGION \
    --quiet
# [END hypercomputer_tpu_infer_gemma4_26b_cluster_cleanup]