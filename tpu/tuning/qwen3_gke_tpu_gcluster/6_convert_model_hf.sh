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

echo "[$(date)] ==================== Submitting Model Conversion Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_model_hf]
./gcluster job submit --name mt-to-hf \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION} \
    --compute-type ${TPU_TYPE} \
    --num-slices 1 \
    --image ${CLOUD_IMAGE_NAME} \
    --await-job-completion \
    --command "[ \"\$JOB_COMPLETION_INDEX\" != \"0\" ] || \
      python3 -m maxtext.checkpoint_conversion.to_huggingface \
        model_name=${MODEL_NAME?} \
        hf_access_token=${HF_TOKEN?} \
        load_parameters_path=gs://${GCS_BUCKET?}/${MODEL_NAME}/trained/sft/checkpoints/1000/model_params/ \
        base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/hf-trained/ \
        skip_jax_distributed_system=true \
        hardware=cpu \
        scan_layers=True \
        use_multimodal=False \
        weight_dtype=bfloat16"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_model_hf]

echo "[$(date)] ==================== Model converted successfully. ===================="
