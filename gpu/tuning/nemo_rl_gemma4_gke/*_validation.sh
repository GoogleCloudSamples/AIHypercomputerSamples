#!/bin/bash
#
#   Copyright 2026 Google LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/job_output.log"
CHECKPOINT_DIR="/data/${RUN_NAME}/step_${GRPO_MAX_STEPS}"
HEAD_POD_NAME=""

dump_debug() {
  echo "========== Debug output =========="
  kubectl get pods -o wide || true
  if [[ -f "${LOG_FILE}" ]]; then
    echo "---------- Last 100 lines of ${LOG_FILE} ----------"
    tail -n 100 "${LOG_FILE}" || true
    echo "---------- Errors in ${LOG_FILE} ----------"
    grep -nE 'Traceback|Error|OOM|out of memory|NCCL WARN' "${LOG_FILE}" | tail -n 40 || true
  fi
  if [[ -n "${HEAD_POD_NAME}" ]]; then
    echo "---------- Contents of /data/${RUN_NAME} ----------"
    kubectl exec "${HEAD_POD_NAME}" -c ray-head -- find "/data/${RUN_NAME}" -maxdepth 3 || true
  fi
}

fail() {
  echo "Validation Failed! $*"
  dump_debug
  exit 1
}

if [[ ! -f "${LOG_FILE}" ]]; then
  fail "Log file ${LOG_FILE} not found."
fi

echo "Expected number of training steps: ${GRPO_MAX_STEPS}"

TRAINING_COUNT="$(grep -c "Training Results:" "${LOG_FILE}" || true)"
echo "Found ${TRAINING_COUNT} completed training steps in ${LOG_FILE}."
if [[ "${TRAINING_COUNT}" -ne "${GRPO_MAX_STEPS}" ]]; then
  fail "Expected ${GRPO_MAX_STEPS} training steps, but found ${TRAINING_COUNT}."
fi

if grep -qiE 'Loss: (nan|-?inf)' "${LOG_FILE}"; then
  fail "The training loss is not finite."
fi
echo "Last reported training loss: $(grep -oP 'Loss: \K[-0-9.e]+' "${LOG_FILE}" | tail -n 1)"

# Verify the final checkpoint on the Lustre volume
HEAD_POD_NAME="$(kubectl get pods --selector=ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "${HEAD_POD_NAME}" ]]; then
  fail "No running Ray head pod found."
fi

echo "Verifying Lustre checkpoint ${CHECKPOINT_DIR} inside ${HEAD_POD_NAME}..."
if ! kubectl exec "${HEAD_POD_NAME}" -c ray-head -- test -d "${CHECKPOINT_DIR}/policy/weights"; then
  fail "Checkpoint ${CHECKPOINT_DIR}/policy/weights not found on the Lustre volume."
fi
kubectl exec "${HEAD_POD_NAME}" -c ray-head -- du -sh "${CHECKPOINT_DIR}" || true

echo "Validation Succeeded!"
