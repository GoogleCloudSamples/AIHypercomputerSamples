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

# [START hypercomputer_gpu_infer_qwen38_2t_fetch_manifest]
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/qwen38-2t/qwen3.8-2.4t-nvfp4-stage-weights-job.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/refs/heads/main/gpu/inference/qwen38-2t/qwen3.8-2.4t-nvfp4-multihost-a4-gcsfuse.yaml
# [END hypercomputer_gpu_infer_qwen38_2t_fetch_manifest]

# [START hypercomputer_gpu_infer_qwen38_2t_stage_weights_logs]
kubectl logs -f -l job-name=qwen3-8-2-4t-stage-weights -c download --prefix --max-log-requests=4
sleep 5
kubectl logs -f -l job-name=qwen3-8-2-4t-stage-weights -c upload --prefix --max-log-requests=4
# [END hypercomputer_gpu_infer_qwen38_2t_stage_weights_logs]

# [START hypercomputer_gpu_infer_qwen38_2t_poll_ready]
frontend_pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*frontend" | head -n 1)
prefill_ldr_pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*prefill-ldr" | head -n 1)
decode_ldr_pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*decode-ldr" | head -n 1)
echo "Created frontend/prefill/decode leader pods:"
echo "  Frontend:    ${frontend_pod}"
echo "  Prefill Ldr: ${prefill_ldr_pod}"
echo "  Decode Ldr:  ${decode_ldr_pod}"
echo ""
echo "Waiting for pods to be ready..."
for pod in "${frontend_pod}" "${prefill_ldr_pod}" "${decode_ldr_pod}"; do
  if ! kubectl wait --for=condition=Ready "pod/${pod}" --timeout=3600s; then
    echo "Pod ${pod} failed to become Ready within 60 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    kubectl logs "${pod}" --tail=200 >&2 || true
  fi
done
# [END hypercomputer_gpu_infer_qwen38_2t_poll_ready]

# [START hypercomputer_gpu_infer_qwen38_2t_stage_weights_verify]
gcloud storage ls "gs://${GCS_BUCKET}/hf_models/models--nvidia--qwen3_8-2_4t-a95b-nvfp4/*.safetensors" | wc -l
# [END hypercomputer_gpu_infer_qwen38_2t_stage_weights_verify]

# [START hypercomputer_gpu_infer_qwen38_2t_server_logs]
kubectl get pods
POD_NAME="YOUR_POD_NAME"
kubectl logs -f "${POD_NAME}"
# [END hypercomputer_gpu_infer_qwen38_2t_server_logs]

# [START hypercomputer_gpu_infer_qwen38_2t_server_logs_v2]
# monitor prefill leader pod
kubectl logs -f -c main --tail=-1 \
$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*prefill-ldr" | head -n 1)

# monitor decode leader pod
kubectl logs -f -c main --tail=-1 \
$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*decode-ldr" | head -n 1)
# [END hypercomputer_gpu_infer_qwen38_2t_server_logs_v2]

# [START hypercomputer_gpu_infer_qwen38_2t_port_forward]
kubectl port-forward svc/qwen3-8-2-4t-a4-disagg-frontend 8000:8000
# [END hypercomputer_gpu_infer_qwen38_2t_port_forward]
