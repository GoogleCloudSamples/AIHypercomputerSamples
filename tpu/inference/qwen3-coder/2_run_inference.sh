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

# [START hypercomputer_tpu_infer_qwen3_coder_apply_manifest]
kubectl apply -f qwen3-coder-480b-multihost-disagg-v7x.yaml
# [END hypercomputer_tpu_infer_qwen3_coder_apply_manifest]

kubectl wait --for=condition=Ready --timeout=5400s pod/sglang-tpu-prefill-0 pod/sglang-tpu-decode-0
kubectl wait --for=condition=Available --timeout=5400s deployment/sglang-router
