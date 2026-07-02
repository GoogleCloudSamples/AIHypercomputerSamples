#!/bin/bash
#
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

# [START hypercomputer_gpu_train_qwen2_slurm_submit_slurm]
#SBATCH --job-name=qwen2-pretrain-smollm-fineweb
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8 # 8 tasks per node
#SBATCH --gpus-per-task=1   # 1 GPU per task
#SBATCH --partition=a4high
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err

set -euo pipefail
echo "--- Slurm Job Started ---"

# --- STAGE 1: Setup environment and pre-process data on each node's local SSD ---
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 bash -c '
  set -e
  echo "Setting up local environment on $(hostname)..."
  LOCAL_VENV="/mnt/localssd/venv_job_${SLURM_JOB_ID}"
  LOCAL_CACHE="/mnt/localssd/hf_cache_job_${SLURM_JOB_ID}"
  PROCESSED_DATA_DIR="/mnt/localssd/processed_data_${SLURM_JOB_ID}"
  LOCAL_TMP="/mnt/localssd/tmp_job_${SLURM_JOB_ID}"

  rsync -a --info=progress2 ~/./.venv/ ${LOCAL_VENV}/
  mkdir -p ${LOCAL_CACHE} ${PROCESSED_DATA_DIR} ${LOCAL_TMP}

  echo "Pre-processing data on $(hostname)..."
  source ${LOCAL_VENV}/bin/activate
  export TMPDIR="${LOCAL_TMP}"
  export TEMP="${LOCAL_TMP}"
  export TMP="${LOCAL_TMP}"
  export HF_HOME="${LOCAL_CACHE}"
  export HF_DATASETS_CACHE="${LOCAL_CACHE}"
  export HF_MODULES_CACHE="${LOCAL_CACHE}/modules"
  export HF_METRICS_CACHE="${LOCAL_CACHE}/metrics"

  python "${HOME}/preprocess_data.py" \
    --dataset_name "HuggingFaceFW/fineweb-edu" \
    --dataset_config "CC-MAIN-2024-10" \
    --tokenizer_id "Qwen/Qwen2-1.5B" \
    --max_seq_length 1024 \
    --output_path ${PROCESSED_DATA_DIR}

  echo "Setup on $(hostname) complete."
'

# --- STAGE 2: Run the Training Job using the Local Environment ---
echo "--- Starting Training ---"

LOCAL_VENV="/mnt/localssd/venv_job_${SLURM_JOB_ID}"
PROCESSED_DATA_DIR="/mnt/localssd/processed_data_${SLURM_JOB_ID}"
LOCAL_OUTPUT_DIR="/mnt/localssd/outputs_${SLURM_JOB_ID}"

srun --ntasks=$((SLURM_NNODES * 8)) --gpus-per-task=1 bash -c "
  mkdir -p ${LOCAL_OUTPUT_DIR}
  source ${LOCAL_VENV}/bin/activate

  python train.py \
    --model_config_id 'Qwen/Qwen2-1.5B' \
    --preprocessed_data_path ${PROCESSED_DATA_DIR} \
    --output_dir ${LOCAL_OUTPUT_DIR} \
    --per_device_train_batch_size 4 \
    --gradient_accumulation_steps 4 \
    --max_steps 10000 \
    --learning_rate 5e-5 \
    --save_strategy steps \
    --save_steps 500
"

# --- STAGE 3: Copy Final Model from Local SSD to Home Directory ---
echo "--- Copying final model from local SSD to /home ---"
mkdir -p ~/qwen2-from-scratch-on-smollm-fineweb/

srun --nodes=1 --ntasks=1 --ntasks-per-node=1 bash -c "
  rsync -a --info=progress2 ${LOCAL_OUTPUT_DIR}/ ~/qwen2-from-scratch-on-smollm-fineweb/
"

echo "--- Slurm Job Finished ---"
# [END hypercomputer_gpu_train_qwen2_slurm_submit_slurm]
