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

# Ensure JobSet and Kueue controllers are ready before workload submission
kubectl wait --for=condition=Available --timeout=300s deployment/jobset-controller-manager -n jobset-system 2>/dev/null || true
kubectl wait --for=condition=Available --timeout=300s deployment/kueue-controller-manager -n kueue-system 2>/dev/null || true

echo "[$(date)] ==================== Submitting Training Workload... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_train]
./gcluster job submit \
  --name="qwen-rl" \
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
  --command="(echo 190G > /sys/fs/cgroup/memory.max || echo 190G > /sys/fs/cgroup/memory/memory.limit_in_bytes) 2>/dev/null || true && \
    export VLLM_HOST_IP=\$(hostname -I | awk '{print \$1}') && \
    export VLLM_ENABLE_V1_MULTIPROCESSING=0 && \
    python3 -c \"import pathlib, tunix.generate.vllm_sampler as vs; p = pathlib.Path(vs.__file__); p.write_text(p.read_text().replace('reshard_chunk_size: Optional[int] = None', 'reshard_chunk_size: Optional[int] = 4').replace('reshard_chunk_size=self.config.reshard_chunk_size', 'reshard_chunk_size=4'))\" && \
    python3 -c \"import pathlib, re; p = pathlib.Path('/deps/src/maxtext/trainers/post_train/rl/utils_rl.py'); p.write_text(re.sub('optax[.]adamw[(][^)]+[)]', 'optax.adafactor(learning_rate=learning_rate)', p.read_text()))\" && \
    JAX_PLATFORMS=proxy,cpu ENABLE_PATHWAYS_PERSISTENCE=1 \
    python3 -m maxtext.trainers.post_train.rl.train_rl \
    run_name=rl \
    base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ \
    model_name=${MODEL_NAME} \
    load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ \
    hf_access_token=${HF_TOKEN} \
    data_template_path=maxtext/examples/chat_templates/openmathinstruct2_rl.json \
    num_batches=50 \
    num_test_batches=0 \
    batch_size=8 \
    train_micro_batch_size=8 \
    max_target_length=512 \
    max_prefill_predict_length=256 \
    mu_dtype=bfloat16 \
    grad_dtype=bfloat16 \
    rollout_tensor_parallelism=1 \
    rollout_expert_parallelism=4 \
    trainer_devices_fraction=0.5 \
    sampler_devices_fraction=0.5 \
    tokenizer_path='Qwen/Qwen3-30B-A3B-Instruct-2507' \
    ici_tensor_parallelism=2 \
    ici_expert_parallelism=4 \
    ici_fsdp_parallelism=-1 \
    hbm_utilization_vllm=0.55 \
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
# [END hypercomputer_tpu_tune_qwen3_30b_rl_train]
echo "[$(date)] ==================== Training Workload submitted. ===================="

echo "[$(date)] ==================== Waiting for Training Workload to Start... ===================="
POD_NAME=""
for i in {1..120}; do
  POD_NAME=$(kubectl get pods -l job-name=qwen-rl-pathways-head-0 -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [ -z "$POD_NAME" ]; then
    POD_NAME=$(kubectl get pods -l jobset.sigs.k8s.io/replicatedjob-name=pathways-head,jobset.sigs.k8s.io/jobset-name=qwen-rl -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
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
kubectl wait --for=condition=Ready "pod/${POD_NAME}" --timeout=600s 2>/dev/null || true

# Stream logs in a reconnect loop so XLA compilation silent pauses don't prematurely end the script
while true; do
  CONTAINER_STATE=$(kubectl get pod "${POD_NAME}" -o jsonpath='{.status.containerStatuses[?(@.name=="workload-container")].state.terminated.reason}' 2>/dev/null || echo "")
  if [ -n "$CONTAINER_STATE" ]; then
    break
  fi

  kubectl logs -f "${POD_NAME}" -c workload-container --tail=100 2>/dev/null || true

  CONTAINER_STATE=$(kubectl get pod "${POD_NAME}" -o jsonpath='{.status.containerStatuses[?(@.name=="workload-container")].state.terminated.reason}' 2>/dev/null || echo "")
  if [ -n "$CONTAINER_STATE" ]; then
    break
  fi

  sleep 10
done

echo "Checking final job status..."
EXIT_CODE=""
for i in {1..30}; do
  EXIT_CODE=$(kubectl get pod "${POD_NAME}" -o jsonpath='{.status.containerStatuses[?(@.name=="workload-container")].state.terminated.exitCode}' 2>/dev/null || true)
  if [ -n "$EXIT_CODE" ]; then
    break
  fi
  sleep 2
done

if [ "$EXIT_CODE" != "0" ]; then
  echo "ERROR: Training container did not succeed (Exit Code: ${EXIT_CODE:-unknown})."
  kubectl get pod "${POD_NAME}" -o yaml | grep -A 15 containerStatuses || true
  exit 1
fi
echo "[$(date)] ==================== Training Workload completed successfully. ===================="
