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

echo "[$(date)] ==================== Submitting Training Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_train]
gcluster job submit \
  --name="qwen-training" \
  --cluster="${CLUSTER_NAME}" \
  --project="${PROJECT}" \
  --location="${REGION}" \
  --num-slices=1 \
  --image="${CLOUD_IMAGE_NAME}" \
  --compute-type="${COMPUTE_TYPE}" \
  --topology="${TOPOLOGY}" \
  --pathways \
  --pathways-gcs-location="gs://${GCS_BUCKET}/pathways/" \
  --env="GRPC_DNS_RESOLVER=native" \
  --pathways-proxy-env="GRPC_DNS_RESOLVER=native" \
  --pathways-server-env="GRPC_DNS_RESOLVER=native" \
  --pathways-worker-env="GRPC_DNS_RESOLVER=native" \
  --command="export VLLM_HOST_IP=\$(hostname -I | awk '{print \$1}'); \
      JAX_PLATFORMS=proxy,cpu ENABLE_PATHWAYS_PERSISTENCE=1 \
      python3 -m maxtext.trainers.post_train.rl.train_rl \
      run_name=rl \
      base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ \
      model_name=${MODEL_NAME} \
      load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ \
      hf_access_token=${HF_TOKEN} \
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
      hbm_utilization_vllm=0.2 \
      remat_policy=full \
      async_scheduling=False \
      allow_split_physical_axes=true \
      debug.rl=True \
      vllm_hf_overrides='{architectures: [\"MaxTextForCausalLM\"]}' \
      vllm_additional_config=\"{'maxtext_config': {'model_name': '${MODEL_NAME}', 'allow_split_physical_axes': 'true', weight_dtype: bfloat16}}\""
# [END hypercomputer_tpu_tune_qwen3_30b_rl_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Training Workload to Complete... ===================="
echo "Waiting for pod to be scheduled..."
POD_NAME=""
ATTEMPTS=0
while [ -z "$POD_NAME" ]; do
  if [ $ATTEMPTS -ge 60 ]; then
    echo "ERROR: Timeout (10 minutes) waiting for pod to be scheduled."
    exit 1
  fi
  POD_NAME=$(kubectl get pods -l job-name=qwen-training-pathways-head-0 -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [ -z "$POD_NAME" ]; then
    POD_NAME=$(kubectl get pods -l jobset.sigs.k8s.io/replicatedjob-name=pathways-head,jobset.sigs.k8s.io/jobset-name=qwen-training -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  fi
  if [ -z "$POD_NAME" ]; then
    sleep 10
    ATTEMPTS=$((ATTEMPTS+1))
  fi
done

echo "Found training pod: $POD_NAME"
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
  echo "ERROR: Training pod did not succeed (Status: $POD_STATUS)."
  exit 1
fi
echo "[$(date)] ==================== Training Workload completed successfully. ===================="
