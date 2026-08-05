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

# Monitor GKE pod initialization and startup status in real time
# [START hypercomputer_gpu_infer_llama4scout_g4_monitor_pods]
kubectl get pods -w
# [END hypercomputer_gpu_infer_llama4scout_g4_monitor_pods]

# Start port forwarding in background
# [START hypercomputer_gpu_infer_llama4scout_g4_port_forwarding]
nohup kubectl port-forward "svc/${USER}-serving-llama-4-g4-svc" 8000:8000 > /dev/null 2>&1 &
# [END hypercomputer_gpu_infer_llama4scout_g4_port_forwarding]

# Run curl test
curl http://localhost:8000/health

# Test inference via OpenAI-compatible Chat API
# [START hypercomputer_gpu_infer_llama4scout_g4_test_inference]
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-4-Scout-17B-16E-Instruct",
    "messages": [
      {"role": "user", "content": "Hello! Are you ready to work on the G4 GPU?"}
    ],
    "max_tokens": 60,
    "temperature": 0.2
  }'
# [END hypercomputer_gpu_infer_llama4scout_g4_test_inference]

# Run stream_chat.sh test
# [START hypercomputer_gpu_infer_llama4scout_g4_stream_chat]
./gpu-recipes/inference/a4/single-host-serving/vllm/stream_chat.sh \
  "What is the meaning of life?" \
  "meta-llama/Llama-4-Scout-17B-16E-Instruct"
# [END hypercomputer_gpu_infer_llama4scout_g4_stream_chat]

# Run benchmark
# [START hypercomputer_gpu_infer_llama4scout_g4_run_benchmark]
kubectl exec -it deployment/${USER}-serving-llama-4-g4 -c serving -- \
  vllm bench serve \
    --model meta-llama/Llama-4-Scout-17B-16E-Instruct \
    --dataset-name random \
    --ignore-eos \
    --num-prompts 1100 \
    --random-input-len 1000 \
    --random-output-len 1000 \
    --port 8000 \
    --backend vllm \
    --max-concurrency 64
# [END hypercomputer_gpu_infer_llama4scout_g4_run_benchmark]

# Uninstall Helm release
# [START hypercomputer_gpu_infer_llama4scout_g4_delete_helm]
helm uninstall "${RELEASE_NAME}"
kubectl delete configmap "${RELEASE_NAME}-launcher"
kubectl delete secret hf-secret
# [END hypercomputer_gpu_infer_llama4scout_g4_delete_helm]

# Deleting Cloud Storage Bucket
# [START hypercomputer_gpu_infer_llama4scout_g4_delete_gcs_bucket]
gcloud storage rm -r "gs://${GCS_BUCKET}"
# [END hypercomputer_gpu_infer_llama4scout_g4_delete_gcs_bucket]

# Clean up local workspace and build artifacts
# [START hypercomputer_gpu_infer_llama4scout_g4_delete_local_workspace]
rm -rf "${SCRIPT_DIR}/build_rtx6000"
# [END hypercomputer_gpu_infer_llama4scout_g4_delete_local_workspace]
