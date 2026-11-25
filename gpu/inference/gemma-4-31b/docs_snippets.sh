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

set -euo pipefail

# [START hypercomputer_gpu_infer_gemma4_31b_port_forward]
kubectl port-forward service/vllm-gemma4-31b-service 8000:8000
# [END hypercomputer_gpu_infer_gemma4_31b_port_forward]

: <<'EOF'
# [START hypercomputer_gpu_infer_gemma4_31b_interact_output]
{
  "id": "chatcmpl-9f3c7b2e1a4d4c8e9b0a1234567890ab",
  "object": "chat.completion",
  "created": 1763368000,
  "model": "google/gemma-4-31B-it",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "reasoning_content": null,
        "content": "The sky appears blue because of Rayleigh scattering...",
        "tool_calls": []
      },
      "logprobs": null,
      "finish_reason": "stop",
      "stop_reason": 106
    }
  ],
  "usage": {
    "prompt_tokens": 15,
    "total_tokens": 198,
    "completion_tokens": 183,
    "prompt_tokens_details": null
  },
  "prompt_logprobs": null
}
# [END hypercomputer_gpu_infer_gemma4_31b_interact_output]
EOF
