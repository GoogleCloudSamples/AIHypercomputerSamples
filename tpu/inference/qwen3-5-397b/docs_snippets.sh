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

# [START hypercomputer_tpu_infer_qwen3_5_397b_nodepool_create_flex_start]
gcloud container node-pools create "${NODE_POOL_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --machine-type="${MACHINE_TYPE}" \
    --location="${REGION}" \
    --node-locations="${ZONE}" \
    --project="${PROJECT_ID}" \
    --num-nodes=1 \
    --flex-start
# [END hypercomputer_tpu_infer_qwen3_5_397b_nodepool_create_flex_start]

# [START hypercomputer_tpu_infer_qwen3_5_397b_server_logs]
kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l app=vllm-qwen3-5 --timeout=900s
kubectl logs deployment/vllm-qwen3-5 -c vllm-tpu -f
# [END hypercomputer_tpu_infer_qwen3_5_397b_server_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_port_forward]
kubectl port-forward service/vllm-qwen3-5-service 8000:8000
# [END hypercomputer_tpu_infer_qwen3_5_397b_port_forward]

# [START hypercomputer_tpu_infer_qwen3_5_397b_benchmark_logs]
kubectl logs -f qwen3-5-bench-8k1k
# [END hypercomputer_tpu_infer_qwen3_5_397b_benchmark_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_auth]
gcloud auth login
gcloud auth application-default login
# [END hypercomputer_tpu_infer_qwen3_5_397b_auth]
