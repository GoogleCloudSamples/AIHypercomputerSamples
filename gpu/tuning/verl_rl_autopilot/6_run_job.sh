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

# [START hypercomputer_gpu_train_ray_verl_auto_create_env]
if [ ! -d "env" ]; then
  virtualenv -p $(which python3) env
else
  echo "Found virtual environment env, not recreating"
fi
source env/bin/activate
pip3 install ray[default]
# [END hypercomputer_gpu_train_ray_verl_auto_create_env]  

# 1. Modify runtime-env.yaml based on GPU type if needed
# (e.g. if we are using H200, we need tuner_config_a3u.txtpb)
if [[ "${GPU_TYPE:-}" == *"h200"* ]]; then
    echo "H200 GPU detected. Updating NCCL_TUNER_CONFIG_PATH in runtime-env.yaml..."
    # [START hypercomputer_gpu_train_ray_verl_auto_seth200]
    sed -i 's|/usr/local/gib/configs/tuner_config_a4.txtpb|/usr/local/gib/configs/tuner_config_a3u.txtpb|g' runtime-env.yaml
    # [END hypercomputer_gpu_train_ray_verl_auto_seth200]
fi

# 2. Port forwarding setup
# [START hypercomputer_gpu_train_ray_verl_auto_get_svc]
SVC_NAME="$(kubectl get svc -l "ray.io/node-type=head" -o jsonpath='{..metadata.name}')"
echo "Ray head service name: ${SVC_NAME}"
# [END hypercomputer_gpu_train_ray_verl_auto_get_svc]

if [ -z "${SVC_NAME}" ]; then
    echo "No service found for label ray.io/node-type=head"
    kubectl get svc -n "${NAMESPACE}"
    exit 1
fi

# Start port forwarding in background with auto-restart
# [START hypercomputer_gpu_train_ray_verl_auto_ray_port_fwd]
echo "Starting auto-restarting port-forwarding to ${SVC_NAME} on port 8265..."
run_port_forward() {
    while true; do
        kubectl port-forward svc/"${SVC_NAME}" 8265:8265 -n "${NAMESPACE}" >/dev/null 2>&1 || true
        sleep 1
    done
}
run_port_forward &
PF_LOOP_PID=$!
# [END hypercomputer_gpu_train_ray_verl_auto_ray_port_fwd]

# Ensure we kill port forwarding on exit
cleanup() {
    echo "Cleaning up..."
    if [ -n "${PF_LOOP_PID:-}" ]; then
        kill "${PF_LOOP_PID}" 2>/dev/null || true
    fi
    fuser -k 8265/tcp >/dev/null 2>&1 || true
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
echo "Submitting Ray job (async)..."
# [START hypercomputer_gpu_train_ray_verl_auto_job_submit]
SUBMIT_OUT=$(ray job submit \
  --address "http://localhost:8265" \
  --no-wait \
  --runtime-env runtime-env.yaml \
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
      actor_rollout_ref.actor.use_torch_compile=False \
      actor_rollout_ref.actor.fsdp_config.use_torch_compile=False \
      actor_rollout_ref.ref.use_torch_compile=False \
      actor_rollout_ref.ref.fsdp_config.use_torch_compile=False \
      trainer.total_epochs=2")
# [END hypercomputer_gpu_train_ray_verl_auto_job_submit]

JOB_ID=$(echo "$SUBMIT_OUT" | grep "submitted successfully" | awk -F"'" '{print $2}')
echo "Job submitted successfully. Job ID: ${JOB_ID}"

# Follow logs
while true; do
    STATUS=$(ray job status "${JOB_ID}" --address "http://localhost:8265" 2>/dev/null | grep "Status for job" | awk -F" " '{print $NF}')
    
    if [ -z "$STATUS" ]; then
        echo "Unable to get job status. Retrying..."
        sleep 5
        continue
    fi

    if [[ "$STATUS" == "SUCCEEDED" || "$STATUS" == "FAILED" || "$STATUS" == "STOPPED" ]]; then
        echo "Job finished with status: ${STATUS}"
        ray job logs "${JOB_ID}" --address "http://localhost:8265" || true
        if [[ "$STATUS" == "FAILED" ]]; then
            exit 1
        fi
        break
    fi
    
    echo "Streaming logs (will restart if connection is lost)..."
    ray job logs "${JOB_ID}" --address "http://localhost:8265" --follow || true
    
    sleep 5
done

echo "Job execution completed."
