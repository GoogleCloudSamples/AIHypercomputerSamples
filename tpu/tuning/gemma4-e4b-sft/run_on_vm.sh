#!/bin/bash
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

# shellcheck disable=SC1091

set -euo pipefail

cd "${HOME}"
export UV_VENV_CLEAR=1
OUTPUTS_FILE="${HOME}/gemma4-e4b-sft-outputs.env"
rm -f "${OUTPUTS_FILE}"

apt_jobs_running() {
  local unit state
  for unit in apt-daily.service apt-daily-upgrade.service; do
    state=$(systemctl show --property=ActiveState --value "${unit}" 2>/dev/null || true)
    case "${state}" in
      active|activating|deactivating) return 0 ;;
    esac
  done
  return 1
}
for _ in $(seq 1 60); do
  apt_jobs_running || break
  echo "Waiting for boot-time apt jobs to finish..."
  sleep 10
done

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_0]
sudo apt-get update
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_0]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_1]
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o DPkg::Lock::Timeout=600 \
    build-essential cmake ninja-build
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_1]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_2]
curl -LsSf https://astral.sh/uv/0.13.5/install.sh | sh
source "${HOME}/.local/bin/env"
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_2]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_3]
uv python install 3.12
uv venv --python 3.12 --seed maxtext_venv
source maxtext_venv/bin/activate
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_3]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_4]
UV_TORCH_BACKEND=cpu uv pip install "maxtext[tpu-post-train]==0.2.4" --resolution=lowest
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_4]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_5]
install_tpu_post_train_extra_deps
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_maxtext_5]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_tune_0_env]
export HF_TOKEN="YOUR_HF_TOKEN"
export MODEL_NAME="gemma4-e4b"
export HF_MODEL_ID="google/gemma-4-E4B-it"
export MODEL_CHECKPOINT_DIRECTORY="/dev/shm/${MODEL_NAME}/mt-format"
export USE_PATHWAYS=0 # Set to 1 for Pathways, 0 for McJAX
export LAZY_LOAD_TENSORS=False # True to use lazy load, False to use eager load.
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_tune_0_env]
export HF_TOKEN="${YOUR_HF_TOKEN}"

rm -rf "${MODEL_CHECKPOINT_DIRECTORY:?}"

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_tune_1_convert]
python3 -m maxtext.checkpoint_conversion.to_maxtext \
    model_name="${MODEL_NAME?}" \
    hf_access_token="${HF_TOKEN?}" \
    base_output_directory="${MODEL_CHECKPOINT_DIRECTORY?}" \
    scan_layers=False \
    use_multimodal=False \
    hardware=cpu \
    skip_jax_distributed_system=true \
    checkpoint_storage_use_zarr3=$((1 - USE_PATHWAYS)) \
    checkpoint_storage_use_ocdbt=$((1 - USE_PATHWAYS)) \
    --hf_model_path="${HF_MODEL_ID?}" \
    --lazy_load_tensors="${LAZY_LOAD_TENSORS?}"
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_tune_1_convert]
echo "[gemma4-e4b-sft] Checkpoint conversion to MaxText finished."

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_tune_2_env]
# -- MaxText configuration --
export BASE_OUTPUT_DIRECTORY="/dev/shm/${MODEL_NAME}/post-train"
RUN_NAME=$(date +%Y-%m-%d-%H-%M-%S)
export RUN_NAME
export STEPS=1000
export PER_DEVICE_BATCH_SIZE=1
export MAX_TARGET_LENGTH=2048

# -- Dataset configuration --
export DATASET_NAME="HuggingFaceH4/ultrachat_200k"
export TRAIN_SPLIT="train_sft"
export TRAIN_DATA_COLUMNS="['messages']"

export MAXTEXT_CKPT_PATH="${MODEL_CHECKPOINT_DIRECTORY}/0/items"
export TPU_ACCELERATOR_TYPE=v6e-8
export TPU_WORKER_ID=0
TPU_NAME=$(hostname)
export TPU_NAME
export TPU_SKIP_MDS_QUERY=1
export TPU_WORKER_HOSTNAMES=localhost
export TPU_TOPOLOGY=2x4
export TPU_CHIPS_PER_HOST_BOUNDS=2,4,1
export TPU_HOST_BOUNDS=1,1,1
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_tune_2_env]

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_tune_3_run]
python3 -m maxtext.trainers.post_train.sft.train_sft \
    run_name="${RUN_NAME?}" \
    base_output_directory="${BASE_OUTPUT_DIRECTORY?}" \
    model_name="${MODEL_NAME?}" \
    tokenizer_path="${HF_MODEL_ID?}" \
    tokenizer_type=huggingface \
    load_parameters_path="${MAXTEXT_CKPT_PATH?}" \
    scan_layers=False \
    per_device_batch_size="${PER_DEVICE_BATCH_SIZE?}" \
    max_target_length="${MAX_TARGET_LENGTH?}" \
    steps="${STEPS?}" \
    hf_path="${DATASET_NAME?}" \
    train_split="${TRAIN_SPLIT?}" \
    train_data_columns="${TRAIN_DATA_COLUMNS?}" \
    profiler=xplane
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_tune_3_run]
echo "[gemma4-e4b-sft] Training finished."

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_tune_4_env]
export HF_EXPORT="/dev/shm/${MODEL_NAME}/hf-trained"
export POST_TRAIN_PATH="${BASE_OUTPUT_DIRECTORY}/${RUN_NAME}/checkpoints/${STEPS}/model_params"
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_tune_4_env]

rm -rf "${HF_EXPORT:?}"

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_tune_5_convert]
python3 -m maxtext.checkpoint_conversion.to_huggingface \
    model_name="${MODEL_NAME?}" \
    load_parameters_path="${POST_TRAIN_PATH?}" \
    base_output_directory="${HF_EXPORT?}" \
    scan_layers=False \
    use_multimodal=False \
    weight_dtype=bfloat16 \
    --hf_model_path="${HF_MODEL_ID?}" \
    --override_model_architecture
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_tune_5_convert]
echo "[gemma4-e4b-sft] Export to Hugging Face format finished."

cat > "${OUTPUTS_FILE}" <<EOF
POST_TRAIN_PATH=${POST_TRAIN_PATH}
HF_EXPORT=${HF_EXPORT}
EOF
echo "[gemma4-e4b-sft] All steps finished. Outputs: ${HF_EXPORT}"
