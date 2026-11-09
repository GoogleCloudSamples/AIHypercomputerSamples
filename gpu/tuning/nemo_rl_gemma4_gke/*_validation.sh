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
TARGET_FILE="${SCRIPT_DIR}/kubernetes-engine-samples/ai-ml/nemo-rl-on-gke/nemoRL/gemma3-27b-it/gemma3-27b-gsm8k.sh"
LOG_FILE="${SCRIPT_DIR}/kubernetes-engine-samples/ai-ml/nemo-rl-on-gke/nemoRL/gemma3-27b-it/logs/job_output.log"

if [ ! -f "${LOG_FILE}" ]; then
    echo "Validation Failed. Log file ${LOG_FILE} not found."
    exit 1
fi

# Extract expected step count from gemma3-27b-gsm8k.sh
echo "Reading expected step count from gemma3-27b-gsm8k.sh..."
if ! EXPECTED_STEPS=$(grep -oP 'grpo\.max_num_steps=\K\d+' "${TARGET_FILE}"); then
    echo "Error: Could not extract 'grpo.max_num_steps' from ${TARGET_FILE}." >&2
    exit 1
fi
echo "Expected number of training steps: ${EXPECTED_STEPS}"

# Count occurrences of "Training Results:" in job_output.log
declare -r TRAINING_COUNT="$(grep -o "Training Results:" "${LOG_FILE}" | wc -l)"
echo "Found ${TRAINING_COUNT} completed training steps in job_output.log."
if [[ "${TRAINING_COUNT}" -ne "${EXPECTED_STEPS}" ]]; then
    echo "Validation Failed! Expected ${EXPECTED_STEPS} training steps, but found ${TRAINING_COUNT}."
    exit 1
fi

# Verify checkpoint on the Lustre disk
export HEAD_POD_NAME=$(kubectl get pods --selector=ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')
if [ -z "$HEAD_POD_NAME" ]; then
    echo "Error: No running Ray head pod found."
    exit 1
fi

echo "Verifying Lustre checkpoint /data/nemo_rl_gemma3_27b_3_17/step_${EXPECTED_STEPS} inside ${HEAD_POD_NAME}..."
if ! kubectl exec "${HEAD_POD_NAME}" -c ray-head -- test -d "/data/nemo_rl_gemma3_27b_3_17/step_${EXPECTED_STEPS}"; then
    echo "Validation Failed! Checkpoint directory step_${EXPECTED_STEPS} not found on Lustre volume."
    exit 1
fi

echo "Validation Succeeded!"