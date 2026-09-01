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

echo "Cleaning up any residual qwen-hf-to-mt workload..."
xpk workload delete --workload "qwen-hf-to-mt" --cluster "${CLUSTER_NAME}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
kubectl delete jobset qwen-hf-to-mt 2>/dev/null || true

echo "[$(date)] ==================== Submitting Model Conversion Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_convert_model]
xpk workload create \
  --workload "qwen-hf-to-mt" \
  --docker-image $CLOUD_IMAGE_NAME \
  --cluster ${CLUSTER_NAME} \
  --tpu-type=${TPU_TYPE} \
  --num-slices=1 \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --command "[ \"\$JOB_COMPLETION_INDEX\" != \"0\" ] || \
  python3 -m maxtext.checkpoint_conversion.to_maxtext \
  model_name=${MODEL_NAME} \
  hf_access_token=${HF_TOKEN} \
  --hf_model_path='Qwen/Qwen3-30B-A3B-Instruct-2507' \
  base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/ \
  scan_layers=True \
  use_multimodal=False \
  skip_jax_distributed_system=true \
  checkpoint_storage_use_zarr3=0 \
  checkpoint_storage_use_ocdbt=0 \
  hardware=cpu \
  --lazy_load_tensors=True"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_convert_model]

echo "[$(date)] ==================== Waiting for Model Conversion to Complete... ===================="
echo "Waiting for conversion pod to be created..."
POD_NAME=""
for i in {1..60}; do
  POD_NAME=$(kubectl get pods --no-headers 2>/dev/null | grep qwen-hf-to-mt | awk '{print $1}' | head -n 1) || true
  if [ -n "$POD_NAME" ]; then
    break
  fi
  sleep 5
done

if [ -n "$POD_NAME" ]; then
  echo "Found conversion pod: $POD_NAME"
  echo "Waiting for pod to start running (timeout: 20 minutes)..."

  MAX_WAIT_START=120
  WAIT_COUNT=0
  while true; do
    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$POD_STATUS" == "Running" || "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi

    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT_START ]; then
      echo "ERROR: Timed out waiting for pod $POD_NAME to start running. Current status: $POD_STATUS"
      kubectl describe pod $POD_NAME || true
      exit 1
    fi
    sleep 10
  done

  echo "Tailing logs... (this will block until the conversion finishes)"
  kubectl logs -f $POD_NAME || true

  echo "Waiting for pod to reach completion status (timeout: 180 minutes)..."
  MAX_WAIT_FINISH=1080
  WAIT_FINISH_COUNT=0
  while true; do
    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi

    WAIT_FINISH_COUNT=$((WAIT_FINISH_COUNT + 1))
    if [ $WAIT_FINISH_COUNT -ge $MAX_WAIT_FINISH ]; then
      echo "ERROR: Timed out waiting for pod $POD_NAME to finish conversion."
      kubectl describe pod $POD_NAME || true
      exit 1
    fi
    sleep 10
  done

  if [ "$POD_STATUS" != "Succeeded" ]; then
    echo "ERROR: Conversion pod did not succeed (Status: $POD_STATUS)."
    kubectl logs --tail=100 $POD_NAME || true
    exit 1
  fi
  echo "[$(date)] ==================== Model converted successfully. ===================="
else
  echo "ERROR: Could not find the conversion pod. It may have failed to schedule."
  exit 1
fi
