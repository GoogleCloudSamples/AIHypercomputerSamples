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

# Maximum time to wait for the training job to finish
train_timeout_seconds=7200

# Ensure JobSet and Kueue controllers are ready before workload submission.
kubectl wait --for=condition=Available --timeout=300s deployment/jobset-controller-manager -n jobset-system
kubectl wait --for=condition=Available --timeout=300s deployment/kueue-controller-manager -n kueue-system

echo "[$(date)] ==================== Configuring the Muse Glimmer 30B workload... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_set_config]
export CONFIG=muse_glimmer_30b_fused_ce
export EXTRA="--training.max-context-length=8192 --training.num-tokens-per-microbatch-per-dp-rank=8192"
export WORKLOAD_NAME="${CLUSTER_NAME}-mg30b"
# [END hypercomputer_tpu_train_muse_glimmer_30b_set_config]

echo "[$(date)] ==================== Submitting the training job ${WORKLOAD_NAME}... ===================="
# On the first submission, gcluster asks whether to create the default Kueue resources.
# The here-string answers "Y" so that the script runs unattended.
{
# [START hypercomputer_tpu_train_muse_glimmer_30b_submit_job]
./gcluster job submit \
  --skip-prereqs \
  --mount "${BASE_OUTPUT_DIR};/job-logs;rw" \
  --name "${WORKLOAD_NAME}" --cluster "${CLUSTER_NAME}" \
  --project "${PROJECT_ID}" --location "${ZONE}" \
  --restarts 0 \
  --compute-type v6e-64 --topology "${TOPOLOGY}" --num-slices 1 \
  --image "${WORKLOAD_IMAGE}" \
  --gke-disable-parallel-containers \
  --env=PYTHONUNBUFFERED=1 \
  --env=WORKERS_0_HOSTNAME=${WORKLOAD_NAME}-main-job-0-0.${WORKLOAD_NAME} \
  --env=JAX_PLATFORMS= \
  --env="TORCHRUN_WORKLOAD_OVERRIDE=--training.steps=30 --dump-folder=/job-logs/${WORKLOAD_NAME} --metrics.save-tb-folder=tb --metrics.enable-tensorboard --debug.save-config-file=torchtitan_config.json --module=torchtitan.experiments.tpu.muse_glimmer --config=${CONFIG} ${EXTRA}" \
  --command "torchrun --nnodes=${NNODES} --nproc_per_node=${NPROC_PER_NODE} --rdzv_backend=static --rdzv_endpoint=\${WORKERS_0_HOSTNAME}:29501 --node_rank=\${TPU_WORKER_ID} -m torchtitan.experiments.tpu.train \${TORCHRUN_WORKLOAD_OVERRIDE}"
# [END hypercomputer_tpu_train_muse_glimmer_30b_submit_job]
} <<< "Y"

echo "[$(date)] ==================== Waiting for ${WORKLOAD_NAME} to finish (timeout ${train_timeout_seconds}s)... ===================="
leader_selector="jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME},batch.kubernetes.io/job-completion-index=0,jobset.sigs.k8s.io/job-index=0"
start_time=$(date +%s)
while true; do
  completed=$(kubectl get jobset "${WORKLOAD_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Completed")].status}' 2>/dev/null || true)
  failed=$(kubectl get jobset "${WORKLOAD_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)

  if [ "${completed}" = "True" ]; then
    echo "[$(date)] JobSet ${WORKLOAD_NAME} completed."
    break
  fi

  if [ "${failed}" = "True" ]; then
    echo "[$(date)] Error: JobSet ${WORKLOAD_NAME} failed." >&2
    kubectl describe jobset "${WORKLOAD_NAME}" >&2 || true
    kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME}" >&2 || true
    kubectl logs -l "${leader_selector}" -c workload-container --tail=200 >&2 || true
    exit 1
  fi

  elapsed=$(( $(date +%s) - start_time ))
  if [ "${elapsed}" -ge "${train_timeout_seconds}" ]; then
    echo "[$(date)] Error: timeout waiting for JobSet ${WORKLOAD_NAME} to finish." >&2
    kubectl get jobset,workloads >&2 || true
    kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME}" >&2 || true
    kubectl logs -l "${leader_selector}" -c workload-container --tail=200 >&2 || true
    exit 1
  fi

  pod_phases=$(kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME}" --no-headers 2>/dev/null | awk '{print $3}' | sort | uniq -c | tr -s ' \n' ' ' || true)
  last_step=$(kubectl logs -l "${leader_selector}" -c workload-container --tail=500 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'step: *[0-9]+' | tail -n 1 || true)
  echo "[$(date)] Elapsed ${elapsed}s. Pods:${pod_phases:- none yet}. Last step: ${last_step:-<none yet>}"
  sleep 60
done

echo "[$(date)] ==================== Training job completed. ===================="
