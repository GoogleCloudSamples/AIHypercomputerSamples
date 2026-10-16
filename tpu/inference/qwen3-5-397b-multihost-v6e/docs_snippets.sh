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

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_count_shards]
gcloud storage ls "gs://${GCS_BUCKET}/Qwen/Qwen3-30B-A3B-FP8/*.safetensors" | wc -l
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_count_shards]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_deploy]
sed -i "s/<GCS_BUCKET>/${GCS_BUCKET}/g" v6e_qwen3_server_multi.yaml
kubectl apply -f v6e_qwen3_server_multi.yaml
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_deploy]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_download_logs]
kubectl wait --for=condition=Ready pod -l job-name=download-qwen3 --timeout=120s
kubectl logs -f job/download-qwen3
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_download_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_server_logs]
# Prefill logs
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=prefill -f --tail=-1

# Decode logs
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=decode -f --tail=-1
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_server_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_benchmark_logs]
kubectl wait --for=condition=complete job/vllm-qwen3-30b-pd-disagg-v6e-tester
kubectl logs -f job/vllm-qwen3-30b-pd-disagg-v6e-tester
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_benchmark_logs]
