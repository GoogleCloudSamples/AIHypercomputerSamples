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

export WORKLOAD_NAME="${WORKLOAD_NAME:-${CLUSTER_NAME}-mg30b}"
expected_steps=30
leader_selector="jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME},batch.kubernetes.io/job-completion-index=0,jobset.sigs.k8s.io/job-index=0"

echo "[$(date)] ==================== Starting validation of ${WORKLOAD_NAME}... ===================="

echo "Checking that JobSet ${WORKLOAD_NAME} completed..."
completed=$(kubectl get jobset "${WORKLOAD_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Completed")].status}' 2>/dev/null || true)
if [ "${completed}" = "True" ]; then
  echo "JobSet ${WORKLOAD_NAME} has the Completed condition."
elif kubectl get jobset "${WORKLOAD_NAME}" >/dev/null 2>&1; then
  echo "Validation failed: JobSet ${WORKLOAD_NAME} exists but is not Completed." >&2
  kubectl describe jobset "${WORKLOAD_NAME}" >&2 || true
  exit 1
else
  echo "JobSet ${WORKLOAD_NAME} is no longer present (it might have been removed after its TTL). Validating logs and outputs only."
fi

pods=$(kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME}" --no-headers 2>/dev/null || true)
if [ -n "${pods}" ]; then
  echo "Checking that all ${NNODES} worker Pods succeeded..."
  succeeded=$(kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=${WORKLOAD_NAME}" --field-selector=status.phase=Succeeded --no-headers 2>/dev/null | wc -l || true)
  if [ "${succeeded}" -ne "${NNODES}" ]; then
    echo "Validation failed: ${succeeded}/${NNODES} Pods of ${WORKLOAD_NAME} succeeded." >&2
    echo "${pods}" >&2
    exit 1
  fi
  echo "All ${succeeded} Pods succeeded."
fi

echo "Collecting training logs from the leader Pod..."
train_logs=$(kubectl logs -l "${leader_selector}" -c workload-container --tail=-1 2>/dev/null || true)

if ! echo "${train_logs}" | grep -q 'step:'; then
  echo "No training logs found using kubectl. Reading training metrics from Cloud Logging..."
  train_logs=$(gcloud logging read 'resource.type="k8s_container" AND resource.labels.cluster_name="'$CLUSTER_NAME'" AND resource.labels.pod_name:"'$WORKLOAD_NAME'-main-job-0-0-" AND resource.labels.container_name="workload-container" AND textPayload:"step:"' \
    --project "$PROJECT_ID" --freshness=6h --order=asc --format='value(textPayload)' 2>/dev/null || true)
fi

# Strip ANSI color codes and keep only the per-step metric lines.
step_lines=$(echo "${train_logs}" | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'step: *[0-9]+.*loss: *[0-9.]+' || true)
if [ -z "${step_lines}" ]; then
  echo "Validation failed: no 'step: ... loss: ...' lines found in the training logs." >&2
  echo "${train_logs}" | tail -n 100 >&2
  exit 1
fi

echo "Training metrics (unique steps):"
echo "${step_lines}" | awk '{ match($0, /step: *[0-9]+/); s = substr($0, RSTART, RLENGTH); if (!seen[s]++) print }'

# Each of the 4 local ranks in the leader Pod can print the same step line, so
# keep the first loss value reported for each step
read -r first_step first_loss last_step last_loss < <(echo "${step_lines}" | awk '
  {
    match($0, /step: *[0-9]+/); step = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", step); step += 0
    match($0, /loss: *[0-9.]+/); loss = substr($0, RSTART, RLENGTH); sub(/loss: */, "", loss)
    if (!(step in losses)) { losses[step] = loss }
    if (min == "" || step < min) { min = step }
    if (max == "" || step > max) { max = step }
  }
  END { print min, losses[min], max, losses[max] }')

echo "First step: ${first_step} (loss ${first_loss}). Last step: ${last_step} (loss ${last_loss})."

if [ "${last_step}" -lt "${expected_steps}" ]; then
  echo "Validation failed: expected training to reach step ${expected_steps}, but the last logged step is ${last_step}." >&2
  exit 1
fi

if echo "${train_logs}" | sed 's/\x1b\[[0-9;]*m//g' | grep -qiE 'step: *[0-9]+.*loss: *[-+]?(nan|inf)'; then
  echo "Validation failed: the training logs contain a NaN or Inf loss." >&2
  exit 1
fi

if ! awk -v a="${first_loss}" -v b="${last_loss}" 'BEGIN { exit !(b < a) }'; then
  echo "Validation failed: loss did not decrease (step ${first_step}: ${first_loss}, step ${last_step}: ${last_loss})." >&2
  exit 1
fi
echo "Loss decreased from ${first_loss} to ${last_loss}."

echo "Checking the training outputs in Cloud Storage..."
outputs=$(gcloud storage ls -r "${BASE_OUTPUT_DIR}/${WORKLOAD_NAME}/" 2>/dev/null || true)
if ! echo "${outputs}" | grep -q 'torchtitan_config.json'; then
  echo "Validation failed: torchtitan_config.json not found in ${BASE_OUTPUT_DIR}/${WORKLOAD_NAME}/." >&2
  exit 1
fi
if ! echo "${outputs}" | grep -q '/tb/.*tfevents'; then
  echo "Validation failed: TensorBoard event files (tb/**/events.out.tfevents.*) not found in ${BASE_OUTPUT_DIR}/${WORKLOAD_NAME}/." >&2
  exit 1
fi
echo "Found torchtitan_config.json and TensorBoard event files."

echo "[$(date)] ==================== Validation passed! ===================="
