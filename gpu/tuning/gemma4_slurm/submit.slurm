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

# shellcheck disable=SC2016

# [START hypercomputer_gpu_tune_gemma4_slurm_submit_slurm]
#!/bin/bash
#SBATCH --job-name=gemma4-finetune
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1 # 1 task per node
#SBATCH --gpus-per-node=8   # 8 GPUs per node
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --partition=a4high
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

set -euo pipefail
echo "--- Slurm Job Started ---"

export MODEL_ID="${MODEL_ID:-google/gemma-4-31B-it}"
export DATASET_NAME="${DATASET_NAME:-philschmid/gretel-synthetic-text-to-sql}"
export FINAL_MODEL_DIR="${FINAL_MODEL_DIR:-${HOME}/gemma4-text-to-sql-finetuned}"
export GPUS_PER_NODE=8

export LOCAL_VENV="/mnt/localssd/venv_job_${SLURM_JOB_ID}"
export LOCAL_CACHE="/mnt/localssd/hf_cache_job_${SLURM_JOB_ID}"
export LOCAL_OUTPUT_DIR="/mnt/localssd/outputs_${SLURM_JOB_ID}"

# --- STAGE 1: Copy the environment and download the model and dataset to local SSD on all nodes ---
srun --ntasks="${SLURM_NNODES}" --ntasks-per-node=1 bash -c '
  set -euo pipefail
  echo "Setting up local environment on $(hostname)..."
  rsync -a ~/.venv/ "${LOCAL_VENV}/"
  mkdir -p "${LOCAL_CACHE}"

  echo "Downloading ${MODEL_ID} and ${DATASET_NAME} on $(hostname)..."
  HF_HOME="${LOCAL_CACHE}" HF_DATASETS_CACHE="${LOCAL_CACHE}" "${LOCAL_VENV}/bin/python" -c "
import sys
from datasets import load_dataset
from huggingface_hub import snapshot_download
snapshot_download(sys.argv[1])
load_dataset(sys.argv[2], split=sys.argv[3])
" "${MODEL_ID}" "${DATASET_NAME}" train
  echo "Setup on $(hostname) complete."
'

# --- STAGE 2: Run the training job using the local environment ---
echo "--- Starting Training ---"
mkdir -p "${LOCAL_OUTPUT_DIR}"

srun --ntasks="${SLURM_NNODES}" --ntasks-per-node=1 bash -c '
  set -euo pipefail

  # Ensure nccl-gib is at version 1.1.2-1
  GIB_VERSION="1.1.2-1"
  INSTALLED_VERSION="$(dpkg-query -W -f="\${Version}" nccl-gib 2>/dev/null || echo "not_installed")"
  if [ "${INSTALLED_VERSION}" != "${GIB_VERSION}" ]; then
    echo "Installing nccl-gib ${GIB_VERSION} on $(hostname) (found ${INSTALLED_VERSION})..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq --allow-change-held-packages "nccl-gib=${GIB_VERSION}"
  fi

  if [ -f /usr/local/gib/scripts/set_nccl_env.sh ]; then
    echo "Sourcing set_nccl_env.sh"
    set +u
    source /usr/local/gib/scripts/set_nccl_env.sh
    set -u
  fi
  export LD_LIBRARY_PATH=/usr/local/gib/lib64:${LD_LIBRARY_PATH:-}

  export HF_HOME="${LOCAL_CACHE}"
  export HF_DATASETS_CACHE="${LOCAL_CACHE}"
  export HF_HUB_OFFLINE=1

  MASTER_ADDR=$(scontrol show hostnames "${SLURM_JOB_NODELIST}" | head -n 1)
  MASTER_PORT=29500

  # Use accelerate launch to run the distributed FSDP job
  "${LOCAL_VENV}/bin/python" -m accelerate.commands.launch \
    --config_file ~/accelerate_config.yaml \
    --machine_rank "${SLURM_NODEID}" \
    --main_process_ip "${MASTER_ADDR}" \
    --main_process_port "${MASTER_PORT}" \
    --num_machines "${SLURM_NNODES}" \
    --num_processes $((SLURM_NNODES * GPUS_PER_NODE)) \
    ~/train.py \
    --model_id "${MODEL_ID}" \
    --dataset_name "${DATASET_NAME}" \
    --output_dir "${LOCAL_OUTPUT_DIR}" \
    --per_device_train_batch_size 4 \
    --gradient_accumulation_steps 4 \
    --num_train_epochs 3 \
    --learning_rate 1e-5 \
    --save_strategy steps \
    --save_steps 50
'

# --- STAGE 3: Copy the final model from local SSD to the home directory ---
echo "--- Copying final model from local SSD to /home ---"
# This command runs only on the first node of the job allocation
# and copies the final model back to the persistent shared directory.
srun --nodes=1 --ntasks=1 --ntasks-per-node=1 bash -c '
  set -euo pipefail
  mkdir -p "${FINAL_MODEL_DIR}"
  rsync -a --delete "${LOCAL_OUTPUT_DIR}/" "${FINAL_MODEL_DIR}/"
'

echo "--- Slurm Job Finished ---"
# [END hypercomputer_gpu_tune_gemma4_slurm_submit_slurm]
