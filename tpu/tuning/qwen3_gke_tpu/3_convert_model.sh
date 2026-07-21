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
# [START hypercomputer_tpu_tune_qwen3_sft_convert_model]
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
  base_output_directory=gs://${GCS_BUCKET}/qwen-3-14b/max-text-format/ \
  scan_layers=True \
  use_multimodal=False \
  skip_jax_distributed_system=true \
  hardware=cpu \
  --lazy_load_tensors=True"
# [END hypercomputer_tpu_tune_qwen3_sft_convert_model]
echo "[$(date)] ==================== Waiting for Model Conversion to Complete... ===================="
# Give the cluster a moment to schedule the pod
sleep 15
# Find the pod created by the conversion workload
POD_NAME=$(kubectl get pods | grep qwen-hf-to-mt | awk '{print $1}' | head -n 1) || true

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

  echo "Tailing logs... (this will block until the conversion finishes)"
  kubectl logs -f $POD_NAME || true
  
  # Give Kubernetes a moment to update the pod's phase after logs stream finishes
  for i in {1..10}; do
    POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}')
    if [[ "$POD_STATUS" == "Succeeded" || "$POD_STATUS" == "Failed" ]]; then
      break
    fi
    sleep 3
  done

  if [ "$POD_STATUS" != "Succeeded" ]; then
    echo "ERROR: Conversion pod did not succeed (Status: $POD_STATUS)."
    exit 1
  fi
  echo "[$(date)] ==================== Model converted successfully. ===================="
else
  echo "ERROR: Could not find the conversion pod. It may have failed to schedule."
  exit 1
fi
