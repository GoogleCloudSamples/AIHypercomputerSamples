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
for i in {1..30}; do
  POD_NAME=$(kubectl get pods --no-headers 2>/dev/null | grep qwen-hf-to-mt | awk '{print $1}' | head -n 1) || true
  if [ -n "$POD_NAME" ]; then
    break
  fi
  sleep 5
done

if [ -n "$POD_NAME" ]; then
  echo "Found conversion pod: $POD_NAME"
  echo "Waiting for pod to start running (this can take 5-10 minutes if autoscaler is provisioning nodes)..."
  while true; do
    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}')
    if [[ "$POD_STATUS" == "Running" || "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi
    sleep 10
  done

  echo "Tailing logs and monitoring workload until completion..."
  INITIAL_ATTACH=true
  UNKNOWN_COUNT=0
  while true; do
    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null) || POD_STATUS="Unknown"
    POD_STATUS="${POD_STATUS:-Unknown}"
    if [[ "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi
    if [[ "$POD_STATUS" == "Unknown" ]]; then
      UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
      if [ $UNKNOWN_COUNT -ge 12 ]; then
        echo "ERROR: Pod $POD_NAME status unknown or not found for 2 minutes."
        exit 1
      fi
    else
      UNKNOWN_COUNT=0
    fi

    if [ "$INITIAL_ATTACH" = true ]; then
      echo "Streaming logs (pod phase: $POD_STATUS)..."
      kubectl logs -f $POD_NAME || true
      INITIAL_ATTACH=false
    else
      echo "Streaming logs (pod phase: $POD_STATUS)..."
      kubectl logs -f $POD_NAME --tail=50 || true
    fi

    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null) || POD_STATUS="Unknown"
    POD_STATUS="${POD_STATUS:-Unknown}"
    if [[ "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi
    echo "Log stream disconnected; pod is still $POD_STATUS. Reconnecting in 10s..."
    sleep 10
  done

  # Give Kubernetes a brief moment to update the pod's phase after container finishes
  if [[ "$POD_STATUS" != "Succeeded" && "$POD_STATUS" != "Failed" ]]; then
    for i in {1..6}; do
      POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null) || POD_STATUS="Unknown"
      POD_STATUS="${POD_STATUS:-Unknown}"
      if [[ "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
        break
      fi
      sleep 5
    done
  fi

  if [ "$POD_STATUS" != "Succeeded" ]; then
    echo "ERROR: Conversion pod did not succeed (Status: $POD_STATUS)."
    echo "Recent pod logs:"
    kubectl logs $POD_NAME --tail=100 || true
    exit 1
  fi
  echo "[$(date)] ==================== Model converted successfully. ===================="
else
  echo "ERROR: Could not find the conversion pod. It may have failed to schedule."
  exit 1
fi
