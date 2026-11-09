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

# [START hypercomputer_gpu_tune_gemma3_slurm_submit_slurm]
#!/bin/bash
#SBATCH --job-name=gemma3-finetune
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1 # 1 task per node
#SBATCH --gpus-per-node=8   # 8 GPUs per node
#SBATCH --partition=a4high
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

set -e
echo "--- Slurm Job Started ---"

# --- STAGE 1: Copy Environment to Local SSD on all nodes ---
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 bash -c '
  echo "Setting up local environment on $(hostname)..."
  LOCAL_VENV="/mnt/localssd/venv_job_${SLURM_JOB_ID}"
  LOCAL_CACHE="/mnt/localssd/hf_cache_job_${SLURM_JOB_ID}"
  rsync -a --info=progress2 ~/./.venv/ ${LOCAL_VENV}/
  mkdir -p ${LOCAL_CACHE}
  echo "Setup on $(hostname) complete."
'

# --- STAGE 2: Run the Training Job using the Local Environment ---
echo "--- Starting Training ---"

LOCAL_VENV="/mnt/localssd/venv_job_${SLURM_JOB_ID}"
LOCAL_CACHE="/mnt/localssd/hf_cache_job_${SLURM_JOB_ID}"
LOCAL_OUTPUT_DIR="/mnt/localssd/outputs_${SLURM_JOB_ID}"
mkdir -p ${LOCAL_OUTPUT_DIR}

# This is the main training command.
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 bash -c '
  # Ensure nccl-gib is at version 1.1.2-1
  INSTALLED_VERSION=$(dpkg-query -W -f="\${Version}" nccl-gib 2>/dev/null || echo "not_installed")
  if [ "${INSTALLED_VERSION}" != "1.1.2-1" ]; then
    echo "Upgrading nccl-gib to 1.1.2-1..."
    sudo apt-get update && sudo apt-get install -y --allow-change-held-packages nccl-gib=1.1.2-1
  fi

  source '"${LOCAL_VENV}"'/bin/activate

  export HF_HOME='"${LOCAL_CACHE}"'
  export HF_DATASETS_CACHE='"${LOCAL_CACHE}"'

  if [ -f /usr/local/gib/scripts/set_nccl_env.sh ]; then
    echo "Sourcing set_nccl_env.sh"
    source /usr/local/gib/scripts/set_nccl_env.sh
  fi
  export LD_LIBRARY_PATH=/usr/local/gib/lib64:${LD_LIBRARY_PATH:-}

  export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
  export MASTER_PORT=29500

  # Use accelerate launch to properly run the distributed FSDP job
  accelerate launch \
    --config_file ~/accelerate_config.yaml \
    --machine_rank $SLURM_NODEID \
    --main_process_ip $MASTER_ADDR \
    --main_process_port $MASTER_PORT \
    --num_machines $SLURM_NNODES \
    --num_processes $((SLURM_NNODES * 8)) \
    ~/train.py \
    --model_id google/gemma-3-12b-pt \
    --output_dir '"${LOCAL_OUTPUT_DIR}"' \
    --per_device_train_batch_size 1 \
    --gradient_accumulation_steps 8 \
    --num_train_epochs 3 \
    --learning_rate 1e-5 \
    --save_strategy steps \
    --save_steps 100
'

# --- STAGE 3: Copy Final Model from Local SSD to Home Directory ---
echo "--- Copying final model from local SSD to /home ---"
# This command runs only on the first node of the job allocation
# and copies the final model back to the persistent shared directory.
srun --nodes=1 --ntasks=1 --ntasks-per-node=1 bash -c "
  rsync -a --info=progress2 ${LOCAL_OUTPUT_DIR}/ ~/gemma-12b-text-to-sql-finetuned/
"

echo "--- Slurm Job Finished ---"
# [END hypercomputer_gpu_tune_gemma3_slurm_submit_slurm]
