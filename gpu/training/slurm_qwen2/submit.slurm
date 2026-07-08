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
#SBATCH --ntasks-per-node=1  # 1 main srun task on the node that manages accelerate
#SBATCH --gpus-per-node=8    # access to all 8 GPUs on the node
#SBATCH --partition=a4high
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err

set -euo pipefail
echo "--- Slurm Job Started ---"

# --- STAGE 1: Setup environment and pre-process data on each node's local SSD ---
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 --gpu-bind=none bash -c '
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

export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export MASTER_PORT=29505

# Network and initialization debugging configurations
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,COLL
export TORCH_DISTRIBUTED_DEBUG=INFO
export NCCL_IB_DISABLE=0

# Launching with full GPU access enabled for accelerate
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 --gpu-bind=none bash -c "
  mkdir -p ${LOCAL_OUTPUT_DIR}
  source ${LOCAL_VENV}/bin/activate

  # Reset the forced Slurm isolation to expose all 8 GPUs to the processes
  unset CUDA_VISIBLE_DEVICES

  # Retrieve the default network device.
  DETECTED_IFACE=\$(ip route show | grep default | awk '{print \$5}' | head -n 1)
  echo \"[INFO] Automatically detected cluster network interface: \$DETECTED_IFACE\"

  # Dynamic injection of the detected interface into the network configuration
  export NCCL_SOCKET_IFNAME=\"\${DETECTED_IFACE},gpu*\"
  export TP_SOCKET_IFNAME=\"\${DETECTED_IFACE}\"
  export GLOO_SOCKET_IFNAME=\"\${DETECTED_IFACE}\"

  accelerate launch \
    --config_file ~/accelerate_config.yaml \
    --num_machines \$SLURM_NNODES \
    --num_processes \$((SLURM_NNODES * 8)) \
    --machine_rank \$SLURM_NODEID \
    --main_process_ip \$MASTER_ADDR \
    --main_process_port \$MASTER_PORT \
    train.py \
      --model_config_id 'Qwen/Qwen2-1.5B' \
      --preprocessed_data_path ${PROCESSED_DATA_DIR} \
      --output_dir ${LOCAL_OUTPUT_DIR} \
      --per_device_train_batch_size 4 \
      --gradient_accumulation_steps 4 \
      --max_steps 10000 \
      --learning_rate 5e-5 \
      --save_strategy steps \
      --save_steps 500 \
      --logging_steps 1
"

# --- STAGE 3: Copy Final Model from Local SSD to Home Directory ---
echo "--- Copying final model from local SSD to /home ---"
mkdir -p ~/qwen2-from-scratch-on-smollm-fineweb/

srun --nodes=1 --ntasks=1 --ntasks-per-node=1 bash -c "
  rsync -a --info=progress2 ${LOCAL_OUTPUT_DIR}/ ~/qwen2-from-scratch-on-smollm-fineweb/
"

echo "--- Slurm Job Finished ---"
# [END hypercomputer_gpu_train_qwen2_slurm_submit_slurm]
