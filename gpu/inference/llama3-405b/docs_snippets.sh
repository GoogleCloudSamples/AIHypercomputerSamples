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

# [START hypercomputer_gpu_infer_llama3_405b_auth]
gcloud auth login
gcloud auth application-default login
# [END hypercomputer_gpu_infer_llama3_405b_auth]

# [START hypercomputer_gpu_infer_llama3_405b_fetch_manifest]
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/llama3-405b/llama3.1-405b-singlehost-a4.yaml
# [END hypercomputer_gpu_infer_llama3_405b_fetch_manifest]

# [START hypercomputer_gpu_infer_llama3_405b_server_logs]
kubectl get pods
POD_NAME="YOUR_POD_NAME"
kubectl logs -f "${POD_NAME}"
# [END hypercomputer_gpu_infer_llama3_405b_server_logs]

# [START hypercomputer_gpu_infer_llama3_405b_port_forward]
kubectl port-forward svc/llama3-405b-a4-disagg-frontend 8000:8000
# [END hypercomputer_gpu_infer_llama3_405b_port_forward]
