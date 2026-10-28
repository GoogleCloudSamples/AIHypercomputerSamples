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

# [START hypercomputer_tpu_infer_gemma4_26b_auth]
gcloud auth login
gcloud auth application-default login
# [END hypercomputer_tpu_infer_gemma4_26b_auth]

# [START hypercomputer_tpu_infer_gemma4_26b_download_manifest]
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/tpu/inference/gemma-4-26b/gemma4-26b-multihost-v6e-2x4.yaml
# [END hypercomputer_tpu_infer_gemma4_26b_download_manifest]

# [START hypercomputer_tpu_infer_gemma4_26b_port_forward]
kubectl port-forward service/vllm-service 8000:8000
# [END hypercomputer_tpu_infer_gemma4_26b_port_forward]

# [START hypercomputer_tpu_infer_gemma4_26b_text_request]
curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "google/gemma-4-26B-A4B-it",
        "messages": [{"role": "user", "content": "Explain Mixture of Experts in 2 sentences."}],
        "max_tokens": 128
    }'
# [END hypercomputer_tpu_infer_gemma4_26b_text_request]

# [START hypercomputer_tpu_infer_gemma4_26b_image_request]
curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "google/gemma-4-26B-A4B-it",
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?auto=format&fit=crop&w=800&q=80"
                        }
                    },
                    {
                        "type": "text",
                        "text": "Describe the image above"
                    }
                ]
            }
        ],
        "max_tokens": 300,
        "temperature": 0.0,
        "top_p": 1.0
    }'
# [END hypercomputer_tpu_infer_gemma4_26b_image_request]
