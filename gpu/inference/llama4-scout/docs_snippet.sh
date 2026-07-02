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

# [START hypercomputer_gpu_infer_llama4scout_port_forward]
kubectl port-forward service/llm-service 8000:8000
# [END hypercomputer_gpu_infer_llama4scout_port_forward]

# [START hypercomputer_gpu_infer_llama4scout_27b_deploy_cleanup]
kubectl delete -f vllm-l4-17b.yaml
kubectl delete secret hf-secret
# [END hypercomputer_gpu_infer_llama4scout_27b_deploy_cleanup]
