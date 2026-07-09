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

echo "[$(date)] ==================== Deploying the model... ===================="
# [START hypercomputer_gpu_infer_deepseek31_deploy]
envsubst < vllm-deepseek3-1-base.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_deepseek31_deploy]

echo "Deploying the model and tracking progress..."
# [START hypercomputer_gpu_infer_deepseek31_deploy_wait]
kubectl wait \
  --for=condition=Available \
  --timeout=7200s deployment/deepseek3-1-deploy
# [END hypercomputer_gpu_infer_deepseek31_deploy_wait]
