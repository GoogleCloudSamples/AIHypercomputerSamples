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
# [START hypercomputer_tpu_tune_gemma4_26b_rl_train]
./gcluster job submit \
  --name="gemma4-training" \
  --num-slices=1 \
  --image="${CLOUD_IMAGE_NAME}" \
  --compute-type="${COMPUTE_TYPE}" \
  --topology="${TOPOLOGY}" \
  --pathways \
  --pathways-gcs-location="gs://${GCS_BUCKET}/pathways/" \
  --gke-ttl-after-finished="24h" \
  --restarts=0 \
  --env="GRPC_DNS_RESOLVER=native" \
  --env="FLAGS_pathways_enforce_subset_devices_form_subslice=false" \
  --pathways-proxy-env="GRPC_DNS_RESOLVER=native" \
  --pathways-proxy-env="FLAGS_pathways_enforce_subset_devices_form_subslice=false" \
  --pathways-server-env="GRPC_DNS_RESOLVER=native" \
  --pathways-server-env="FLAGS_pathways_enforce_subset_devices_form_subslice=false" \
  --pathways-worker-env="GRPC_DNS_RESOLVER=native" \
  --pathways-worker-env="FLAGS_pathways_enforce_subset_devices_form_subslice=false" \
  --command="export VLLM_HOST_IP=\$(hostname -I | awk '{print \$1}') && \
    export VLLM_ENABLE_V1_MULTIPROCESSING=0 && \
    python3 -c \"import pathlib, re; p = pathlib.Path('/deps/src/maxtext/trainers/post_train/rl/utils_rl.py'); p.write_text(re.sub('optax[.]adamw[(][^)]+[)]', 'optax.adafactor(learning_rate=learning_rate)', p.read_text()))\" && \
    JAX_PLATFORMS=proxy,cpu ENABLE_PATHWAYS_PERSISTENCE=1 \
    python3 -m maxtext.trainers.post_train.rl.train_rl \
    run_name=rl \
    base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ \
    model_name=${MODEL_NAME} \
    scan_layers=False \
    load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ \
    hf_access_token=${HF_TOKEN} \
    data_template_path=maxtext/examples/chat_templates/openmathinstruct2_rl.json \
    num_batches=50 \
    batch_size=4 \
    train_micro_batch_size=4 \
    max_target_length=640 \
    max_prefill_predict_length=256 \
    mu_dtype=bfloat16 \
    grad_dtype=bfloat16 \
    rollout_tensor_parallelism=4 \
    rollout_expert_parallelism=1 \
    trainer_devices_fraction=0.5 \
    sampler_devices_fraction=0.5 \
    tokenizer_path='google/gemma-4-26b-a4b-it' \
    ici_tensor_parallelism=2 \
    ici_expert_parallelism=4 \
    ici_fsdp_parallelism=-1 \
    hbm_utilization_vllm=0.7 \
    remat_policy=full \
    async_scheduling=False \
    allow_split_physical_axes=true \
    ragged_gather_reduce_fallback=True \
    enable_dp_attention=False \
    decode_sampling_temperature=0.8 \
    decode_sampling_top_k=50 \
    decode_sampling_nucleus_p=0.95 \
    learning_rate=2e-5 \
    learning_rate_schedule_steps=100 \
    rl.num_generations=4 \
    rl.reshard_chunk_size=4 \
    debug=True \
    vllm_hf_overrides='{\"architectures\": [\"MaxTextForCausalLM\"]}' \
    vllm_additional_config=\"{'maxtext_config': {'model_name': '${MODEL_NAME}', 'model_call_mode': 'inference', 'enable_dp_attention': false, 'allow_split_physical_axes': true, 'use_ragged_sort': false, 'ragged_gather_reduce_fallback': true, 'prefuse_moe_weights': true, 'weight_dtype': 'bfloat16'}}\""
# [END hypercomputer_tpu_tune_gemma4_26b_rl_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Training Workload to Start... ===================="
POD_NAME=""
for i in {1..120}; do
  POD_NAME=$(kubectl get pods -l job-name=gemma4-training-pathways-head-0 -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [ -z "$POD_NAME" ]; then
    POD_NAME=$(kubectl get pods -l jobset.sigs.k8s.io/replicatedjob-name=pathways-head,jobset.sigs.k8s.io/jobset-name=gemma4-training -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  fi
  if [ -n "$POD_NAME" ]; then
    echo "Found training pod: ${POD_NAME}"
    break
  fi
  sleep 5
done

if [ -z "$POD_NAME" ]; then
  echo "ERROR: Training pod was not created within timeout."
  exit 1
fi

echo "[$(date)] ==================== Streaming Training Logs... ===================="
# Wait until pod is Ready before tailing logs
kubectl wait --for=condition=Ready pod/${POD_NAME} --timeout=600s 2>/dev/null || true

# A successful run should output metrics with mean_reward > 0.
kubectl logs -f "${POD_NAME}" -c workload-container || true

echo "Checking final job status..."
EXIT_CODE=""
for i in {1..30}; do
  EXIT_CODE=$(kubectl get pod "${POD_NAME}" -o jsonpath='{.status.containerStatuses[?(@.name=="workload-container")].state.terminated.exitCode}' 2>/dev/null || true)
  if [ -n "$EXIT_CODE" ]; then
    break
  fi
  sleep 1
done

if [ "$EXIT_CODE" != "0" ]; then
  echo "ERROR: Training container did not succeed (Exit Code: ${EXIT_CODE:-unknown})."
  exit 1
fi
echo "[$(date)] ==================== Training Workload completed successfully. ===================="
