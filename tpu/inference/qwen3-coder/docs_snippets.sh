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

# [START hypercomputer_tpu_infer_qwen3_coder_check_lws]
kubectl describe pod -n lws-system | grep -A 8 Events
# [END hypercomputer_tpu_infer_qwen3_coder_check_lws]

# [START hypercomputer_tpu_infer_qwen3_coder_download_manifest]
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/tpu/inference/qwen3-coder/qwen3-coder-480b-multihost-disagg-v7x.yaml
# [END hypercomputer_tpu_infer_qwen3_coder_download_manifest]

# [START hypercomputer_tpu_infer_qwen3_coder_check_pods]
kubectl get pods
# [END hypercomputer_tpu_infer_qwen3_coder_check_pods]

# [START hypercomputer_tpu_infer_qwen3_coder_logs]
kubectl logs -f sglang-tpu-prefill-0
kubectl logs -f sglang-tpu-decode-0
# [END hypercomputer_tpu_infer_qwen3_coder_logs]

# [START hypercomputer_tpu_infer_qwen3_coder_port_forward]
kubectl port-forward service/sglang-service 8000:8000
# [END hypercomputer_tpu_infer_qwen3_coder_port_forward]

# [START hypercomputer_tpu_infer_qwen3_coder_test_inference]
curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8",
    "messages": [
      {"role": "user", "content": "Explain quicksort in two sentences."}
    ],
    "max_tokens": 60,
    "temperature": 0.0
  }'
# [END hypercomputer_tpu_infer_qwen3_coder_test_inference]
