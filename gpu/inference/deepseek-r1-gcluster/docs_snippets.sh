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

# [START hypercomputer_gpu_infer_deepseek_r1_download_manifests]
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/inference/deepseek-r1-gcluster/download_model.yaml
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/inference/deepseek-r1-gcluster/deepseek_r1_server.yaml
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/inference/deepseek-r1-gcluster/deepseek_r1_8k_1k.yaml
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/inference/deepseek-r1-gcluster/deepseek_r1_1k_1k.yaml
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/inference/deepseek-r1-gcluster/deepseek_r1_1k_8k.yaml
# [END hypercomputer_gpu_infer_deepseek_r1_download_manifests]

# [START hypercomputer_gpu_infer_deepseek_r1_toolkit_help]
./gcluster --help
# [END hypercomputer_gpu_infer_deepseek_r1_toolkit_help]

# [START hypercomputer_gpu_infer_deepseek_r1_download_job_logs]
kubectl wait --for=condition=Ready pod -l job-name=download-deepseek-r1 --timeout=120s
kubectl logs -f job/download-deepseek-r1
# [END hypercomputer_gpu_infer_deepseek_r1_download_job_logs]

# Confirm all 163 safetensors shards are in the bucket
# [START hypercomputer_gpu_infer_deepseek_r1_verify_model]
gcloud storage ls "gs://${MODEL_BUCKET}/DeepSeek-R1/*.safetensors" | wc -l
# [END hypercomputer_gpu_infer_deepseek_r1_verify_model]

# [START hypercomputer_gpu_infer_deepseek_r1_server_logs]
# monitor leader
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=leader -c vllm-leader -f --tail=-1
# monitor worker
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=worker -c vllm-worker -f --tail=-1
# [END hypercomputer_gpu_infer_deepseek_r1_server_logs]

# [START hypercomputer_gpu_infer_deepseek_r1_port_forward]
kubectl port-forward service/vllm-r1-leader 8080:8080 &
# [END hypercomputer_gpu_infer_deepseek_r1_port_forward]

# [START hypercomputer_gpu_infer_deepseek_r1_text_request]
curl http://localhost:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "deepseek-ai/DeepSeek-R1",
        "messages": [
            {"role": "user", "content": "Explain tensor parallelism in one sentence."}
        ],
        "max_tokens": 100,
        "temperature": 0.6
    }'
# [END hypercomputer_gpu_infer_deepseek_r1_text_request]

# [START hypercomputer_gpu_infer_deepseek_r1_benchmark_8k_1k_logs]
kubectl wait --for=condition=Ready pod/vllm-bench-8k-1k --timeout=120s
kubectl logs -f vllm-bench-8k-1k -c benchmark
# [END hypercomputer_gpu_infer_deepseek_r1_benchmark_8k_1k_logs]

# [START hypercomputer_gpu_infer_deepseek_r1_benchmark_1k_1k_logs]
kubectl wait --for=condition=Ready pod/vllm-bench-1k-1k --timeout=120s
kubectl logs -f vllm-bench-1k-1k -c benchmark
# [END hypercomputer_gpu_infer_deepseek_r1_benchmark_1k_1k_logs]

# [START hypercomputer_gpu_infer_deepseek_r1_benchmark_1k_8k_logs]
kubectl wait --for=condition=Ready pod/vllm-bench-1k-8k --timeout=120s
kubectl logs -f vllm-bench-1k-8k -c benchmark
# [END hypercomputer_gpu_infer_deepseek_r1_benchmark_1k_8k_logs]
