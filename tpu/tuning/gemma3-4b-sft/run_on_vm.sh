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

# [START hypercomputer_tpu_tune_gemma3_sft_maxtext_0]
sudo apt update && sudo apt upgrade -y --fix-missing
# [END hypercomputer_tpu_tune_gemma3_sft_maxtext_0]

# [START hypercomputer_tpu_tune_gemma3_sft_maxtext_1]
sudo apt install -y python3.12 python3.12-venv
# [END hypercomputer_tpu_tune_gemma3_sft_maxtext_1]

# [START hypercomputer_tpu_tune_gemma3_sft_maxtext_2]
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
# [END hypercomputer_tpu_tune_gemma3_sft_maxtext_2]

# [START hypercomputer_tpu_tune_gemma3_sft_maxtext_3]
uv venv --python 3.12 --seed maxtext_venv
source maxtext_venv/bin/activate
# [END hypercomputer_tpu_tune_gemma3_sft_maxtext_3]

# [START hypercomputer_tpu_tune_gemma3_sft_maxtext_4]
uv pip install maxtext[tpu-post-train]==0.2.2 --resolution=lowest
# [END hypercomputer_tpu_tune_gemma3_sft_maxtext_4]

# [START hypercomputer_tpu_tune_gemma3_sft_maxtext_5]
install_maxtext_tpu_post_train_extra_deps
# [END hypercomputer_tpu_tune_gemma3_sft_maxtext_5]

# [START hypercomputer_tpu_tune_gemma3_sft_tune_0_env]
export HF_TOKEN=YOUR_HF_TOKEN
export MODEL_NAME='gemma3-4b'
export MODEL_CHECKPOINT_DIRECTORY=/dev/shm/$MODEL_NAME/mt-format/
export USE_PATHWAYS=0 # Set to 1 for Pathways, 0 for McJAX
export LAZY_LOAD_TENSORS=False # True to use lazy load, False to use eager load.
# [END hypercomputer_tpu_tune_gemma3_sft_tune_0_env]

# [START hypercomputer_tpu_tune_gemma3_sft_tune_1_convert]
python3 -m maxtext.checkpoint_conversion.to_maxtext \
    model_name=${MODEL_NAME?} \
    hf_access_token=${HF_TOKEN?} \
    base_output_directory=${MODEL_CHECKPOINT_DIRECTORY?} \
    scan_layers=True \
    use_multimodal=True \
    hardware=cpu \
    skip_jax_distributed_system=true \
    checkpoint_storage_use_zarr3=$((1 - USE_PATHWAYS)) \
    checkpoint_storage_use_ocdbt=$((1 - USE_PATHWAYS)) \
    --lazy_load_tensors=${LAZY_LOAD_TENSORS?}
# [END hypercomputer_tpu_tune_gemma3_sft_tune_1_convert]

# [START hypercomputer_tpu_tune_gemma3_sft_tune_2_env]
# -- MaxText configuration --
export BASE_OUTPUT_DIRECTORY=/dev/shm/$MODEL_NAME/post-train/
export RUN_NAME=$(date +%Y-%m-%d-%H-%M-%S)
export STEPS=1000
export PER_DEVICE_BATCH_SIZE=1

# -- Dataset configuration --
export DATASET_NAME="HuggingFaceH4/ultrachat_200k"
export TRAIN_SPLIT="train_sft"
export TRAIN_DATA_COLUMNS=['messages']

export MAXTEXT_CKPT_PATH=$MODEL_CHECKPOINT_DIRECTORY/0/items
# [END hypercomputer_tpu_tune_gemma3_sft_tune_2_env]

# [START hypercomputer_tpu_tune_gemma3_sft_tune_3_run]
python3 -m maxtext.trainers.post_train.sft.train_sft \
    run_name=${RUN_NAME?} \
    base_output_directory=${BASE_OUTPUT_DIRECTORY?} \
    model_name=${MODEL_NAME?} \
    load_parameters_path=${MAXTEXT_CKPT_PATH?} \
    per_device_batch_size=${PER_DEVICE_BATCH_SIZE?} \
    steps=${STEPS?} \
    hf_path=${DATASET_NAME?} \
    train_split=${TRAIN_SPLIT?} \
    train_data_columns=${TRAIN_DATA_COLUMNS?} \
    profiler=xplane
# [END hypercomputer_tpu_tune_gemma3_sft_tune_3_run]

# [START hypercomputer_tpu_tune_gemma3_sft_tune_4_env]
export HF_EXPORT=/dev/shm/$MODEL_NAME/hf-trained/
export POST_TRAIN_PATH=$BASE_OUTPUT_DIRECTORY/$RUN_NAME/checkpoints/$STEPS/model_params
# [END hypercomputer_tpu_tune_gemma3_sft_tune_4_env]

# [START hypercomputer_tpu_tune_gemma3_sft_tune_5_convert]
python3 -m maxtext.checkpoint_conversion.to_huggingface \
    model_name=$MODEL_NAME \
    load_parameters_path=$POST_TRAIN_PATH \
    base_output_directory=$HF_EXPORT \
    scan_layers=True \
    use_multimodal=True \
    weight_dtype=bfloat16
# [END hypercomputer_tpu_tune_gemma3_sft_tune_5_convert]
