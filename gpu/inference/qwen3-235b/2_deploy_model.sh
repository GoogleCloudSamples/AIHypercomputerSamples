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

# [START hypercomputer_gpu_infer_qwen3_deploy]
envsubst < qwen3-model-loader.yaml | kubectl apply -f -

echo "Waiting for the model loader job to complete..."
kubectl wait \
    --for=condition=Complete \
    --timeout=1800s job/qwen3-model-loader

kubectl delete job qwen3-model-loader

envsubst < qwen3-235b-deploy.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_qwen3_deploy]

echo "Deploying the model and tracking progress..."
# [START hypercomputer_gpu_infer_qwen3_deploy_wait]
kubectl wait \
    --for=condition=Available \
    --timeout=1800s deployment/vllm-qwen3-deployment
# [END hypercomputer_gpu_infer_qwen3_deploy_wait]
