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

if [ -d "venvp3" ]; then
  source venvp3/bin/activate
fi

# Resolve dynamic cluster name matching the prefix created by setup_cluster.sh
REAL_CLUSTER=$(gcloud container clusters list --project="${PROJECT}" --location="${REGION}" --filter="name~'^${CLUSTER_NAME}'" --format="value(name)" 2>/dev/null | head -n 1 || true)
if [ -n "$REAL_CLUSTER" ]; then
  export CLUSTER_NAME="$REAL_CLUSTER"
  echo "Resolved active target cluster: ${CLUSTER_NAME}"
fi

echo "[$(date)] ==================== Submitting Training Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_train]
xpk workload create-pathways \
  --cluster="${CLUSTER_NAME}" \
  --project="${PROJECT}" \
  --zone="${ZONE}" \
  --docker-image="${CLOUD_IMAGE_NAME}" \
  --workload="qwen-training" \
  --tpu-type="${TPU_TYPE}" \
  --num-slices=1 \
  --command="JAX_PLATFORMS=proxy,cpu JAX_BACKEND_TARGET=grpc://127.0.0.1:29000 ENABLE_PATHWAYS_PERSISTENCE=1 HF_TOKEN=${HF_TOKEN} \
      python3 -m maxtext.trainers.post_train.rl.train_rl \
      run_name=rl \
      base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ \
      model_name=${MODEL_NAME} \
      load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ \
      scan_layers=False \
      dtype=bfloat16 \
      weight_dtype=bfloat16 \
      use_chat_template=True \
      remat_policy='minimal' \
      train_micro_batch_size=1 \
      num_batches=50 \
      per_device_batch_size=1 \
      batch_size=4 \
      rollout_tensor_parallelism=4 \
      rollout_expert_parallelism=4 \
      trainer_devices_fraction=0.5 \
      sampler_devices_fraction=0.5 \
      tokenizer_path='Qwen/Qwen3-30B-A3B-Instruct-2507' \
      ici_tensor_parallelism=4 \
      ici_expert_parallelism=4 \
      hbm_utilization_vllm=0.15 \
      async_scheduling=False \
      allow_split_physical_axes=true \
      debug=True \
      vllm_hf_overrides='{architectures: [\"MaxTextForCausalLM\"]}' \
      vllm_additional_config=\"{'maxtext_config': {'model_name': '${MODEL_NAME}', 'allow_split_physical_axes': 'true', 'weight_dtype': 'bfloat16'}, 'trust_remote_code': true}\""
# [END hypercomputer_tpu_tune_qwen3_30b_rl_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Training Workload to Complete... ===================="
echo "Waiting for training pod to be created..."
POD_NAME=""
for i in {1..30}; do
  POD_NAME=$(kubectl get pods --no-headers 2>/dev/null | grep qwen-training-pathways-head | awk '{print $1}' | head -n 1 || true)
  if [ -n "$POD_NAME" ]; then
    break
  fi
  sleep 5
done

if [ -n "$POD_NAME" ]; then
  echo "Found training pod: $POD_NAME"
  echo "Waiting for pod to start running..."
  while true; do
    POD_STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$POD_STATUS" == "Running" || "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi
    sleep 10
  done

  echo "Tailing logs... (this will block until training finishes)"
  kubectl logs -f "$POD_NAME" -c jax-tpu || true

  echo "Checking execution result of main training container (jax-tpu)..."
  CONTAINER_EXIT_CODE=""
  for i in {1..30}; do
    # Check terminated status in current state or previous state (if K8s restarted container)
    CONTAINER_EXIT_CODE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[?(@.name=="jax-tpu")].state.terminated.exitCode}' 2>/dev/null || echo "")
    if [ -z "$CONTAINER_EXIT_CODE" ]; then
      CONTAINER_EXIT_CODE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[?(@.name=="jax-tpu")].lastState.terminated.exitCode}' 2>/dev/null || echo "")
    fi

    POD_STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

    if [ -n "$CONTAINER_EXIT_CODE" ]; then
      break
    fi
    if [ "$POD_STATUS" == "Succeeded" ]; then
      CONTAINER_EXIT_CODE="0"
      break
    fi
    sleep 5
  done

  if [ "$CONTAINER_EXIT_CODE" == "0" ] || [ "$POD_STATUS" == "Succeeded" ]; then
    echo "[$(date)] ==================== Training completed successfully. ===================="
  else
    echo "ERROR: Training failed. Pod phase: ${POD_STATUS}, Container jax-tpu exit code: ${CONTAINER_EXIT_CODE:-None}."
    kubectl get pod "$POD_NAME" -o yaml | grep -A 10 containerStatuses || true
    exit 1
  fi
else
  echo "ERROR: Could not find the training pod. It may have failed to schedule."
  exit 1
fi
