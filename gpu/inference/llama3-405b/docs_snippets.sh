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
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/llama3-405b/llama3.1-405b-stage-weights-job.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/llama3-405b/llama3.1-405b-singlehost-a4-gcsfuse.yaml
# [END hypercomputer_gpu_infer_llama3_405b_fetch_manifest]

# [START hypercomputer_gpu_infer_llama3_405b_stage_weights_logs]
until kubectl logs -l job-name=llama3-405b-stage-weights -c download >/dev/null 2>&1; do sleep 2; done
kubectl logs -f -l job-name=llama3-405b-stage-weights -c download --prefix

until kubectl logs -l job-name=llama3-405b-stage-weights -c upload >/dev/null 2>&1; do sleep 2; done
kubectl logs -f -l job-name=llama3-405b-stage-weights -c upload --prefix
# [END hypercomputer_gpu_infer_llama3_405b_stage_weights_logs]

# [START hypercomputer_gpu_infer_llama3_405b_stage_weights_verify]
gcloud storage ls "gs://${GCS_BUCKET}/hf_models/models--nvidia--llama-3_1-405b-instruct-fp8/*.safetensors" | wc -l
# [END hypercomputer_gpu_infer_llama3_405b_stage_weights_verify]

# [START hypercomputer_gpu_infer_llama3_405b_poll_ready]
until [[ $(kubectl get pods -l nvidia.com/dynamo-component-type --no-headers 2>/dev/null | wc -l) -eq 3 ]]; do sleep 2; done
frontend_pod=$(kubectl get pods -l "nvidia.com/dynamo-component-type=frontend" -o jsonpath='{.items[*].metadata.name}')
prefill_pod=$(kubectl get pods -l "nvidia.com/dynamo-sub-component-type=prefill" -o jsonpath='{.items[*].metadata.name}')
decode_pod=$(kubectl get pods -l "nvidia.com/dynamo-sub-component-type=decode" -o jsonpath='{.items[*].metadata.name}')
echo "Created frontend/prefill/decode pods:"
echo "  Frontend: ${frontend_pod}"
echo "  Prefill:  ${prefill_pod}"
echo "  Decode:   ${decode_pod}"
echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod "${frontend_pod}" "${prefill_pod}" "${decode_pod}" --timeout=3600s
# [END hypercomputer_gpu_infer_llama3_405b_poll_ready]

# [START hypercomputer_gpu_infer_llama3_405b_server_logs_prefill]
# monitor prefill pod
kubectl logs -f -c main --tail=-1 \
$(kubectl get pods -l "nvidia.com/dynamo-sub-component-type=prefill" -o jsonpath='{.items[*].metadata.name}')
# [END hypercomputer_gpu_infer_llama3_405b_server_logs_prefill]

# [START hypercomputer_gpu_infer_llama3_405b_server_logs_decode]
# monitor decode pod
kubectl logs -f -c main --tail=-1 \
$(kubectl get pods -l "nvidia.com/dynamo-sub-component-type=decode" -o jsonpath='{.items[*].metadata.name}')
# [END hypercomputer_gpu_infer_llama3_405b_server_logs_decode]

# [START hypercomputer_gpu_infer_llama3_405b_server_logs]
kubectl get pods
POD_NAME="YOUR_POD_NAME"
kubectl logs -f "${POD_NAME}"
# [END hypercomputer_gpu_infer_llama3_405b_server_logs]

# [START hypercomputer_gpu_infer_llama3_405b_port_forward]
kubectl port-forward svc/llama3-405b-a4-disagg-frontend 8000:8000
# [END hypercomputer_gpu_infer_llama3_405b_port_forward]
