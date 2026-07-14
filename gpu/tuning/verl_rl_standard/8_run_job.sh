#!/bin/bash

# Copyright 2026 Google LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

source 0_env.sh

if [ ! -d "env" ]; then
  echo "Creating local virtual environment for Ray client..."
  virtualenv -p $(which python3) env
else
  echo "Found virtual environment env, not recreating"
fi
source env/bin/activate
pip3 install ray[default]

# Prepare runtime-env-local.yaml from our local runtime-env.yaml
cp runtime-env.yaml ./runtime-env-local.yaml

# Modify runtime-env-local.yaml based on GPU type if needed
if [[ "${GPU_TYPE:-}" == *"h200"* ]]; then
    echo "H200 GPU detected. Updating NCCL_TUNER_CONFIG_PATH in runtime-env-local.yaml..."
    sed -i 's|/usr/local/gib/configs/tuner_config_a4.txtpb|/usr/local/gib/configs/tuner_config_a3u.txtpb|g' runtime-env-local.yaml
fi

# 2. Port forwarding setup
# Standard RayCluster name is b200-ray-cluster (from ray-cluster-standard.yaml)
# We can also get it dynamically
SVC_NAME="$(kubectl get svc -l "ray.io/node-type=head" -o jsonpath='{..metadata.name}')"
echo "Ray head service name: ${SVC_NAME}"
if [ -z "${SVC_NAME}" ]; then
    echo "No service found for label ray.io/node-type=head"
    kubectl get svc -n "${NAMESPACE}"
    exit 1
fi

echo "Waiting for service ${SVC_NAME} to be available..."
until kubectl get svc "${SVC_NAME}" -n "${NAMESPACE}" &> /dev/null; do
    echo "Waiting for service ${SVC_NAME}..."
    sleep 5
done

# Start port forwarding in background
echo "Starting port-forwarding to ${SVC_NAME} on port 8265..."
kubectl port-forward svc/"${SVC_NAME}" 8265:8265 -n "${NAMESPACE}" &
PF_PID=$!

# Ensure we kill port forwarding on exit
cleanup() {
    if [ -n "${PF_PID:-}" ]; then
        echo "Stopping port forwarding (PID: ${PF_PID})..."
        kill "${PF_PID}" || true
    fi
}
trap cleanup EXIT

# Wait for port to be ready
echo "Waiting for port 8265 to be open..."
TIMEOUT=30
while ! (exec 3<>/dev/tcp/127.0.0.1/8265) 2>/dev/null; do
    sleep 1
    TIMEOUT=$((TIMEOUT - 1))
    if [ $TIMEOUT -eq 0 ]; then
        echo "Error: Port forwarding failed to start in time."
        exit 1
    fi
done
echo "Port 8265 is open. Port-forwarding is ready."

# 3. Submit the job
echo "Submitting Ray job..."
# [START hypercomputer_gpu_train_ray_verl_std_job_submit]
ray -- job submit \
--address "http://localhost:8265" \
--runtime-env runtime-env-local.yaml \
-- \
bash -c "
    cd /data/verl && PYTHONUNBUFFERED=1 python3 -m verl.trainer.main_ppo \
    data.train_files=/data/gsm8k/train.parquet \
    data.val_files=/data/gsm8k/test.parquet \
    data.train_batch_size=256 \
    data.max_prompt_length=512 \
    data.max_response_length=512 \
    actor_rollout_ref.model.path=/data/Qwen2.5-32B-Instruct \
    actor_rollout_ref.actor.optim.lr=1e-5 \
    actor_rollout_ref.actor.ppo_mini_batch_size=256 \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=64 \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=8 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=8 \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.6 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=4 \
    actor_rollout_ref.actor.strategy=fsdp2 \
    algorithm.kl_ctrl.kl_coef=0.001 \
    trainer.logger=console \
    trainer.val_before_train=False \
    trainer.n_gpus_per_node=8 \
    trainer.nnodes=2 \
    trainer.save_freq=10 \
    trainer.test_freq=10 \
    trainer.default_local_dir=/data/verl/checkpoints \
    algorithm.adv_estimator=grpo \
    actor_rollout_ref.rollout.n=8 \
    trainer.total_epochs=2"
# [END hypercomputer_gpu_train_ray_verl_std_job_submit]

echo "Job execution completed."
