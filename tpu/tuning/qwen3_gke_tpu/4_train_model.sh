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

echo "[$(date)] ==================== Submitting Training Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_train]
xpk workload create-pathways \
  --cluster=${CLUSTER_NAME} \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --docker-image=$CLOUD_IMAGE_NAME \
  --workload="qwen-training" \
  --tpu-type=${TPU_TYPE} \
  --num-slices=1 \
  --command="JAX_PLATFORMS=proxy,cpu JAX_BACKEND_TARGET=grpc://127.0.0.1:29000 ENABLE_PATHWAYS_PERSISTENCE=1 \
  python3 -m maxtext.trainers.post_train.sft.train_sft \
  run_name=sft \
  base_output_directory=gs://${GCS_BUCKET}/qwen-3-14b/trained/ \
  model_name=${MODEL_NAME} \
  load_parameters_path=gs://${GCS_BUCKET}/qwen-3-14b/max-text-format/0/items/ \
  hf_access_token=${HF_TOKEN} \
  per_device_batch_size=1 \
  steps=1000 \
  profiler=xplane \
  checkpoint_storage_use_zarr3=0 \
  checkpoint_storage_use_ocdbt=0 \
  enable_single_controller=True"
# [END hypercomputer_tpu_tune_qwen3_sft_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Training Workload to Complete... ===================="
echo "Waiting for training pod to be created..."
POD_NAME=""
for i in {1..30}; do
  POD_NAME=$(kubectl get pods --no-headers 2>/dev/null | grep qwen-training-pathways-head | awk '{print $1}' | head -n 1) || true
  if [ -n "$POD_NAME" ]; then
    break
  fi
  sleep 5
done

if [ -n "$POD_NAME" ]; then
  echo "Found training pod: $POD_NAME"
  echo "Waiting for training container to start running..."
  while true; do
    CONTAINER_STATE=$(kubectl get pod $POD_NAME -o jsonpath='{.status.containerStatuses[?(@.name=="jax-tpu")].state}' 2>/dev/null || echo "")
    if [[ "$CONTAINER_STATE" =~ "running" || "$CONTAINER_STATE" =~ "terminated" ]]; then
      break
    fi
    sleep 5
  done

  echo "Tailing logs... (this will block until training finishes)"
  kubectl logs -f $POD_NAME -c jax-tpu || true

  # Check container exit code
  EXIT_CODE=""
  for i in {1..10}; do
    EXIT_CODE=$(kubectl get pod $POD_NAME -o jsonpath='{.status.containerStatuses[?(@.name=="jax-tpu")].state.terminated.exitCode}' 2>/dev/null || echo "")
    if [ -n "$EXIT_CODE" ]; then
      break
    fi
    sleep 3
  done

  if [ "$EXIT_CODE" != "0" ]; then
    echo "ERROR: Training container failed with exit code ${EXIT_CODE:-unknown}."
    exit 1
  fi
  echo "[$(date)] ==================== Training completed successfully. ===================="
else
  echo "ERROR: Could not find the training pod. It may have failed to schedule."
  exit 1
fi
