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

# [START hypercomputer_gpu_infer_qwen38_2t_auth]
gcloud auth login
gcloud auth application-default login
# [END hypercomputer_gpu_infer_qwen38_2t_auth]

# [START hypercomputer_gpu_infer_qwen38_2t_fetch_manifests]
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/qwen38-2t/qwen3.8-2.4t-nvfp4-multihost-a4.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/qwen38-2t/qwen3.8-2.4t-nvfp4-stage-weights-job.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/qwen38-2t/qwen3.8-2.4t-nvfp4-multihost-a4-gcsfuse.yaml
# [END hypercomputer_gpu_infer_qwen38_2t_fetch_manifests]

# [START hypercomputer_gpu_infer_qwen38_2t_stage_weights_logs]
POD_NAME="YOUR_POD_NAME"
kubectl logs -f "${POD_NAME}"
# [END hypercomputer_gpu_infer_qwen38_2t_stage_weights_logs]

# [START hypercomputer_gpu_infer_qwen38_2t_server_logs]
kubectl get pods
POD_NAME="YOUR_POD_NAME"
kubectl logs -f "${POD_NAME}"
# [END hypercomputer_gpu_infer_qwen38_2t_server_logs]

# [START hypercomputer_gpu_infer_qwen38_2t_port_forward]
kubectl port-forward svc/qwen3-8-2-4t-a4-disagg-frontend 8000:8000
# [END hypercomputer_gpu_infer_qwen38_2t_port_forward]
