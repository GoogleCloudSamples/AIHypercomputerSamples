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
VLLM_OVERRIDES='{\"architectures\":[\"MaxTextForCausalLM\"]}'
VLLM_CONFIG='{\"maxtext_config\":{\"model_name\":\"qwen3-30b-a3b\",\"allow_split_physical_axes\":true,\"weight_dtype\":\"bfloat16\"},\"stop\":[\"<|im_end|>\",\"<|endoftext|>\"],\"include_stop_str_in_output\":false,\"max_tokens\":1024}'

TRAIN_CMD="JAX_PLATFORMS=proxy,cpu JAX_BACKEND_TARGET=grpc://127.0.0.1:29000 ENABLE_PATHWAYS_PERSISTENCE=1 HF_TOKEN=${HF_TOKEN} python3 -m maxtext.trainers.post_train.rl.train_rl run_name=rl base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ model_name=qwen3-30b-a3b load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ scan_layers=False dtype=bfloat16 weight_dtype=bfloat16 use_multimodal=False use_chat_template=True tokenizer_type=huggingface tokenizer_path=Qwen/Qwen3-30B-A3B-Instruct-2507 remat_policy=full train_micro_batch_size=4 batch_size=16 rollout_micro_batch_size=8 num_batches=50 per_device_batch_size=1 rollout_tensor_parallelism=4 rollout_expert_parallelism=4 trainer_devices_fraction=0.5 sampler_devices_fraction=0.5 ici_tensor_parallelism=4 ici_expert_parallelism=4 hbm_utilization_vllm=0.2 use_weight_converter=True async_scheduling=False allow_split_physical_axes=true stop_strings=['<|im_end|>','<|endoftext|>'] vllm_hf_overrides=\"${VLLM_OVERRIDES}\" vllm_additional_config=\"${VLLM_CONFIG}\""

# Wait for JobSet controller and mutating webhook service to be ready
echo "Checking JobSet controller and webhook readiness..."
kubectl wait --for=condition=Available deployment/jobset-controller-manager -n jobset-system --timeout=180s 2>/dev/null || true
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=jobset -n jobset-system --timeout=120s 2>/dev/null || true

# Retry loop for workload creation (protects against transient 'No agent available' webhook errors)
MAX_RETRIES=5
RETRY_DELAY=15
SUCCESS=false

for attempt in $(seq 1 $MAX_RETRIES); do
  echo "Attempt ${attempt}/${MAX_RETRIES}: Submitting workload via xpk..."

  # Clean up any leftover or half-registered workload before retrying
  xpk workload delete \
    --cluster="${CLUSTER_NAME}" \
    --project="${PROJECT}" \
    --zone="${ZONE}" \
    --workload="qwen-training" 2>/dev/null || true

  if xpk workload create-pathways \
    --cluster="${CLUSTER_NAME}" \
    --project="${PROJECT}" \
    --zone="${ZONE}" \
    --docker-image="${CLOUD_IMAGE_NAME}" \
    --workload="qwen-training" \
    --tpu-type="${TPU_TYPE}" \
    --num-slices=1 \
    --command="${TRAIN_CMD}"; then
      echo "Workload successfully created on attempt ${attempt}."
      SUCCESS=true
      break
  else
    echo "WARNING: xpk workload create failed on attempt ${attempt}. Waiting ${RETRY_DELAY}s before retrying..."
    sleep $RETRY_DELAY
    RETRY_DELAY=$((RETRY_DELAY + 10))
  fi
done

if [ "$SUCCESS" != "true" ]; then
  echo "ERROR: Failed to create xpk workload after ${MAX_RETRIES} attempts."
  kubectl get pods -n jobset-system || true
  kubectl get endpoints -n jobset-system || true
  exit 1
fi
# [END hypercomputer_tpu_tune_qwen3_30b_rl_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Training Workload to Complete... ===================="

# 2. Wait up to 10 minutes (120 * 5s) for the head pod to be created by Kueue/JobSet
echo "Waiting for training pod to be created..."
POD_NAME=""
for i in {1..120}; do
  POD_NAME=$(kubectl get pods --no-headers 2>/dev/null | grep qwen-training-pathways-head | awk '{print $1}' | head -n 1 || true)
  if [ -n "$POD_NAME" ]; then
    break
  fi
  sleep 5
done

if [ -z "$POD_NAME" ]; then
  echo "ERROR: Could not find the training pod within 10 minutes. Workload admission or scheduling failed."
  kubectl get workloads -A || true
  kubectl get jobsets -A || true
  exit 1
fi

echo "Found training pod: $POD_NAME"
echo "Waiting for pod to enter Running or terminal phase..."
while true; do
  POD_STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  if [[ "$POD_STATUS" == "Running" || "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
    break
  fi
  sleep 10
done

# 3. Stream logs using pathways-head container
echo "Streaming logs from pathways-head..."
while true; do
  POD_STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

  if [[ "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
    break
  fi

  # Stream logs from pathways-head
  kubectl logs -f "$POD_NAME" -c pathways-head --tail=100 2>/dev/null || true

  # Check if pathways-head container actually terminated before sleeping
  CONTAINER_STATE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[?(@.name=="pathways-head")].state.terminated.reason}' 2>/dev/null || echo "")
  if [ -n "$CONTAINER_STATE" ]; then
    break
  fi

  sleep 10
done

# 4. Final status determination for pathways-head container
echo "Checking execution result of main training container (pathways-head)..."
CONTAINER_EXIT_CODE=""
for i in {1..30}; do
  CONTAINER_EXIT_CODE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[?(@.name=="pathways-head")].state.terminated.exitCode}' 2>/dev/null || echo "")
  if [ -z "$CONTAINER_EXIT_CODE" ]; then
    CONTAINER_EXIT_CODE=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[?(@.name=="pathways-head")].lastState.terminated.exitCode}' 2>/dev/null || echo "")
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
  echo "ERROR: Training failed. Pod phase: ${POD_STATUS}, Container pathways-head exit code: ${CONTAINER_EXIT_CODE:-None}."
  kubectl get pod "$POD_NAME" -o yaml | grep -A 15 containerStatuses || true
  exit 1
fi
