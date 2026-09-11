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

echo "[$(date)] ==================== Submitting Hugging Face Conversion Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_convert_hf]
xpk workload create \
  --cluster=${CLUSTER_NAME} \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --docker-image=$CLOUD_IMAGE_NAME \
  --workload="qwen-mt-to-hf" \
  --tpu-type=${TPU_TYPE} \
  --num-slices=1 \
  --command="[ \"\$JOB_COMPLETION_INDEX\" != \"0\" ] || \
  python3 -m maxtext.checkpoint_conversion.to_huggingface \
  model_name=${MODEL_NAME} \
  hf_access_token=${HF_TOKEN} \
  load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/rl/checkpoints/actor/50/model_params/ \
  base_output_directory=gs://$GCS_BUCKET/${MODEL_NAME}/hf-trained/ \
  skip_jax_distributed_system=true \
  hardware=cpu \
  scan_layers=True \
  use_multimodal=False \
  weight_dtype=bfloat16 \
  --override_model_architecture"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_convert_hf]
echo "[$(date)] ==================== Hugging Face Conversion Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Hugging Face Conversion to Complete... ===================="
echo "Waiting for conversion pod to be created..."
POD_NAME=""
for i in {1..30}; do
  POD_NAME=$(kubectl get pods --no-headers 2>/dev/null | grep qwen-mt-to-hf | awk '{print $1}' | head -n 1) || true
  if [ -n "$POD_NAME" ]; then
    break
  fi
  sleep 5
done

if [ -n "$POD_NAME" ]; then
  echo "Found conversion pod: $POD_NAME"
  echo "Waiting for pod to start running..."
  while true; do
    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null) || POD_STATUS="Unknown"
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
    echo "ERROR: HF conversion pod did not succeed (Status: $POD_STATUS)."
    echo "Recent pod logs:"
    kubectl logs $POD_NAME --tail=100 || true
    exit 1
  fi
  echo "[$(date)] ==================== Hugging Face conversion completed successfully. ===================="
else
  echo "ERROR: Could not find the HF conversion pod. It may have failed to schedule."
  exit 1
fi
