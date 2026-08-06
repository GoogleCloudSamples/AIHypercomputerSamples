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

echo "[$(date)] ==================== Submitting Hugging Face Conversion Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_convert_hf]
gcluster job submit \
  --name="qwen-mt-to-hf" \
  --cluster=${CLUSTER_NAME} \
  --project=${PROJECT} \
  --location=${REGION} \
  --num-slices=1 \
  --image=$CLOUD_IMAGE_NAME \
  --compute-type=${COMPUTE_TYPE} \
  --topology=${TOPOLOGY} \
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
echo "Waiting for pod to be scheduled..."
POD_NAME=""
ATTEMPTS=0
while [ -z "$POD_NAME" ]; do
  if [ $ATTEMPTS -ge 60 ]; then
    echo "ERROR: Timeout (10 minutes) waiting for pod to be scheduled."
    exit 1
  fi
  POD_NAME=$(kubectl get pods -l job-name=qwen-mt-to-hf-main-job-0 -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [ -z "$POD_NAME" ]; then
    sleep 10
    ATTEMPTS=$((ATTEMPTS+1))
  fi
done

echo "Found conversion pod: $POD_NAME"
echo "Waiting for pod to download image and start running..."
while true; do
  POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  if [ "$POD_STATUS" != "Pending" ]; then
    break
  fi
  sleep 10
done

echo "Tailing logs for $POD_NAME..."
kubectl logs -f $POD_NAME

# Wait for Kubernetes to update the pod phase after logs finish
POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath="{.status.phase}" 2>/dev/null || true)
while [ "$POD_STATUS" == "Running" ] || [ "$POD_STATUS" == "Pending" ]; do
  sleep 5
  POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath="{.status.phase}" 2>/dev/null || true)
done

if [ "$POD_STATUS" != "Succeeded" ]; then
  echo "ERROR: Conversion pod did not succeed (Status: $POD_STATUS)."
  exit 1
fi
echo "[$(date)] ==================== Converted back to HF format successfully. ===================="
