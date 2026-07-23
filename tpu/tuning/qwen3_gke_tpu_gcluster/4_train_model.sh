#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

echo "[$(date)] ==================== Submitting Training Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_train]
gcluster job submit --name sft \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION} \
    --compute-type ${TPU_TYPE} \
    --num-slices 1 \
    --image ${CLOUD_IMAGE_NAME} \
    --command "JAX_PLATFORMS=tpu,cpu ENABLE_PJRT_COMPATIBILITY=true JAX_TRACEBACK_FILTERING=off LIBTPU_INIT_ARGS=' --xla_tpu_scoped_vmem_limit_kib=61440 --xla_tpu_bf16_emission_mode=NATIVE_EMISSION --xla_tpu_enable_sparse_core_collective_offload_all_reduce=true --xla_tpu_use_single_sparse_core_for_all_gather_offload=true ' \
      python3 -m maxtext.trainers.post_train.sft.train_sft \
      run_name=sft \
      base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ \
      model_name=${MODEL_NAME} \
      load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ \
      hf_access_token=${HF_TOKEN} \
      per_device_batch_size=1 steps=1000 \
      profiler=xplane \
      checkpoint_storage_use_zarr3=0 \
      checkpoint_storage_use_ocdbt=0 \
      skip_jax_distributed_system=False"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_train]

echo "[$(date)] ==================== Training Workload submitted. ===================="
sleep 15
POD_NAME=$(kubectl get pods -l job-name=sft-main-job-0 -o jsonpath="{.items[0].metadata.name}")

if [ -n "$POD_NAME" ]; then
  echo "Found training pod: $POD_NAME"
  echo "Tailing logs..."
  kubectl logs -f $POD_NAME || true
else
  echo "WARNING: Could not immediately find the training pod. Check workload status using kubectl get pods."
fi
