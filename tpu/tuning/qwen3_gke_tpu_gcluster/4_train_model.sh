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
      dataset_type=hf \
      hf_path=HuggingFaceH4/ultrachat_200k \
      per_device_batch_size=1 steps=1000 \
      profiler=xplane \
      checkpoint_storage_use_zarr3=0 \
      checkpoint_storage_use_ocdbt=0 \
      skip_jax_distributed_system=False"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_train]

echo "[$(date)] ==================== Training Workload submitted. ===================="
echo "Waiting for pod to be scheduled..."
POD_NAME=""
ATTEMPTS=0
while [ -z "$POD_NAME" ]; do
  if [ $ATTEMPTS -ge 60 ]; then
    echo "ERROR: Timeout (10 minutes) waiting for pod to be scheduled."
    exit 1
  fi
  POD_NAME=$(kubectl get pods -l job-name=sft-main-job-0 -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [ -z "$POD_NAME" ]; then
    sleep 10
    ATTEMPTS=$((ATTEMPTS+1))
  fi
done

echo "Found training pod: $POD_NAME"
echo "Waiting for pod to download image and start running..."
while true; do
  POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  if [ "$POD_STATUS" != "Pending" ]; then
    break
  fi
  sleep 10
done

echo "Tailing logs for $POD_NAME..."
kubectl logs -f $POD_NAME

# Wait for Kubernetes to update the pod phase after logs finish
POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath="{.status.phase}" 2>/dev/null || true)
while [ "$POD_STATUS" == "Running" ] || [ "$POD_STATUS" == "Pending" ]; do
  sleep 5
  POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath="{.status.phase}" 2>/dev/null || true)
done

if [ "$POD_STATUS" != "Succeeded" ]; then
  echo "ERROR: Training pod did not succeed (Status: $POD_STATUS)."
  exit 1
fi
echo "[$(date)] ==================== Training Workload completed successfully. ===================="
