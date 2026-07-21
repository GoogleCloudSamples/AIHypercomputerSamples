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

if [ -d "venvp3" ]; then
  source venvp3/bin/activate
fi

echo "[$(date)] ==================== Submitting Training Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_train]
xpk workload create-pathways \
  --cluster=${CLUSTER_NAME} \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --docker-image=$CLOUD_IMAGE_NAME \
  --workload="qwen-training" \
  --tpu-type=${TPU_TYPE} \
  --num-slices=1 \
  --command="JAX_PLATFORMS=proxy JAX_BACKEND_TARGET=grpc://127.0.0.1:29000 ENABLE_PATHWAYS_PERSISTENCE=1 \
  python3 -m maxtext.trainers.post_train.sft.train_sft \
  run_name=sft \
  base_output_directory=gs://${GCS_BUCKET}/qwen-3-14b/trained/ \
  model_name=${MODEL_NAME} \
  load_parameters_path=gs://${GCS_BUCKET}/qwen-3-14b/max-text-format/0/items/ \
  hf_access_token=${HF_TOKEN} \
  per_device_batch_size=1 \
  steps=1000 \
  profiler=xplane \
  checkpoint_storage_use_zarr3=0 \
  checkpoint_storage_use_ocdbt=0 \
  enable_single_controller=True"
# [END hypercomputer_tpu_tune_qwen3_sft_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="
