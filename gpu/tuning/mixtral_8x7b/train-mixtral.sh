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

# [START hypercomputer_gpu_tune_mixtral_slurm_train_sh]
#!/bin/bash
#SBATCH --job-name=mixtral-fsdp
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --partition=a4high
#SBATCH --output=mixtral-%j.out
#SBATCH --error=mixtral-%j.err

set -e
set -x

echo "--- Slurm Job Started ---"

# --- Define Paths ---
LOCAL_SSD_PATH="/mnt/localssd/job_${SLURM_JOB_ID}"
VENV_PATH="${HOME}/.venv/venv-fsdp"
MODEL_PATH="${HOME}/Mixtral-8x7B-v0.1"

# --- STAGE 1: Stage Data to Local SSD on Each Node ---
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 bash -c "
echo '--- Staging on node: $(hostname) ---'
mkdir -p ${LOCAL_SSD_PATH}

echo 'Copying virtual environment...'
rsync -a -q ${VENV_PATH}/ ${LOCAL_SSD_PATH}/venv/

echo 'Copying model weights...'
rsync -a ${MODEL_PATH}/ ${LOCAL_SSD_PATH}/model/

mkdir -p ${LOCAL_SSD_PATH}/hf_cache

echo '--- Staging on $(hostname) complete ---'
"
echo "--- Staging complete on all nodes ---"

# --- STAGE 2: Run the Training Job ---
echo "--- Launching Distributed Training with GIB NCCL Plugin ---"
nodes=( $( scontrol show hostnames "$SLURM_JOB_NODELIST" ) )
head_node=${nodes[0]}
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address)

export MASTER_ADDR=$head_node_ip
export MASTER_PORT=29500

export NCCL_SOCKET_IFNAME=enp0s19

export NCCL_NET=gIB

# export NCCL_DEBUG=INFO # Un-comment to diagnose NCCL issues if needed

srun --cpu-bind=none --accel-bind=g bash -c '
# Activate the environment from the local copy
source '${LOCAL_SSD_PATH}'/venv/bin/activate

# Point Hugging Face cache to the local SSD
export HF_HOME='${LOCAL_SSD_PATH}'/hf_cache

export RANK=$SLURM_PROCID
export WORLD_SIZE=$SLURM_NTASKS
export LOCAL_RANK=$SLURM_LOCALID

export LD_LIBRARY_PATH=/usr/local/gib/lib64:$LD_LIBRARY_PATH
source /usr/local/gib/scripts/set_nccl_env.sh

# --- Launch the training ---
python \
    '${SLURM_SUBMIT_DIR}'/train-mixtral.py \
    --model_id="'${LOCAL_SSD_PATH}'/model/" \
    --output_dir="${HOME}/outputs/mixtral_job_${SLURM_JOB_ID}" \
    --dataset_name="philschmid/gretel-synthetic-text-to-sql" \
    --seed=900913 \
    --bf16=True \
    --num_train_epochs=3 \
    --per_device_train_batch_size=32 \
    --gradient_accumulation_steps=4 \
    --learning_rate=4e-5 \
    --logging_steps=3 \
    --lora_r=32 \
    --lora_alpha=32 \
    --lora_dropout=0.05 \
    --eval_strategy=steps \
    --eval_steps=10 \
    --save_strategy=steps \
    --save_steps=10 \
    --load_best_model_at_end=False \
    --metric_for_best_model=eval_loss \
    --run_inference_after_training \
    --dataset_subset_size=67000
'

# --- STAGE 3: Cleanup ---
echo "--- Cleaning up local SSD on all nodes ---"
srun --ntasks=$SLURM_NNODES --ntasks-per-node=1 bash -c "rm -rf ${LOCAL_SSD_PATH}"

echo "--- Slurm Job Finished ---"
# [END hypercomputer_gpu_tune_mixtral_slurm_train_sh]