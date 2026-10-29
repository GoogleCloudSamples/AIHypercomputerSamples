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

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_count_shards]
gcloud storage ls "gs://${GCS_BUCKET}/Qwen/Qwen3.5-397B-A17B-FP8/*.safetensors" | wc -l
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_count_shards]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_deploy]
envsubst '${GCS_BUCKET} ${VLLM_IMAGE}' < "v7x_qwen3_5_server_multihost_slice.yaml" | kubectl apply -f -
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_deploy]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_download_logs]
kubectl wait --for=condition=Ready pod -l job-name=download-qwen35 --timeout=120s
kubectl logs -f job/download-qwen35
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_download_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_server_logs]
# Prefill logs
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=prefill -f --tail=-1

# Decode logs
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=decode -f --tail=-1
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_server_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_benchmark_logs]
kubectl wait --for=condition=Ready pod -l job-name=vllm-qwen3-5-397b-pd-disagg-v7x-tester --timeout=300s
kubectl logs -f job/vllm-qwen3-5-397b-pd-disagg-v7x-tester
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_benchmark_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_curl_download_job_yaml]
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/tpu/inference/qwen3-5-397b-multihost/download_model.yaml
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_curl_download_job_yaml]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_curl_server_yaml]
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/tpu/inference/qwen3-5-397b-multihost/v7x_qwen3_5_server_multihost_slice.yaml
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_curl_server_yaml]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_curl_benchmark_yaml]
curl -O https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/tpu/inference/qwen3-5-397b-multihost/v7x_qwen3_5_benchmark_multihost_slice.yaml
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_curl_benchmark_yaml]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_flex_start]
gcloud container node-pools create "${NODE_POOL_NAME_0}" \
    --cluster="${CLUSTER_NAME}" \
    --machine-type="${MACHINE_TYPE}" \
    --placement-policy="${WORKLOAD_POLICY_NAME}" \
    --location="${REGION}" \
    --node-locations="${ZONE}" \
    --project="${PROJECT_ID}" \
    --reservation-affinity=none \
    --enable-autoscaling \
    --num-nodes=0 \
    --min-nodes=0 \
    --max-nodes=2 \
    --flex-start

gcloud container node-pools create "${NODE_POOL_NAME_1}" \
    --cluster="${CLUSTER_NAME}" \
    --machine-type="${MACHINE_TYPE}" \
    --placement-policy="${WORKLOAD_POLICY_NAME}" \
    --location="${REGION}" \
    --node-locations="${ZONE}" \
    --project="${PROJECT_ID}" \
    --reservation-affinity=none \
    --enable-autoscaling \
    --num-nodes=0 \
    --min-nodes=0 \
    --max-nodes=2 \
    --flex-start
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_nodepool_create_flex_start]
# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_count_shards]
gcloud storage ls "gs://${GCS_BUCKET}/Qwen/Qwen3.5-397B-A17B-FP8/*.safetensors" | wc -l
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_count_shards]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_deploy]
envsubst '${GCS_BUCKET} ${VLLM_IMAGE}' < "v6e_qwen3_server_multihost_slice.yaml" | kubectl apply -f -
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
kubectl wait --for=condition=complete job/vllm-qwen3-5-397b-pd-disagg-v6e-tester
kubectl logs -f job/vllm-qwen3-5-397b-pd-disagg-v6e-tester
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_benchmark_logs]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_nodepool_create_spot]
gcloud container node-pools create "${NODE_POOL_NAME_0}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --cluster="${CLUSTER_NAME}" \
    --node-locations="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --tpu-topology=2x4 \
    --num-nodes=2 \
    --spot

gcloud container node-pools create "${NODE_POOL_NAME_1}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --cluster="${CLUSTER_NAME}" \
    --node-locations="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --tpu-topology=2x4 \
    --num-nodes=2 \
    --spot
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_nodepool_create_spot]

# [START hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_nodepool_create_flex_start]
gcloud container node-pools create "${NODE_POOL_NAME_0}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --cluster="${CLUSTER_NAME}" \
    --node-locations="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --tpu-topology=2x4 \
    --reservation-affinity=none \
    --enable-autoscaling \
    --num-nodes=0 \
    --min-nodes=0 \
    --max-nodes=2 \
    --flex-start

gcloud container node-pools create "${NODE_POOL_NAME_1}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --cluster="${CLUSTER_NAME}" \
    --node-locations="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --tpu-topology=2x4 \
    --reservation-affinity=none \
    --enable-autoscaling \
    --num-nodes=0 \
    --min-nodes=0 \
    --max-nodes=2 \
    --flex-start
# [END hypercomputer_tpu_infer_qwen3_5_397b_multihost_v6e_nodepool_create_flex_start]
