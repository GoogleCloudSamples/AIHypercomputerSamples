#!/bin/bash
#
#  Copyright 2026 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/job_output.log"
mkdir -p "${LOG_DIR}"
rm -f "${LOG_FILE}"

echo "[$(date)] ========== Finding the Ray head pod =========="
HEAD_POD_NAME="$(kubectl get pods --selector=ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "${HEAD_POD_NAME}" ]]; then
  echo "Error: No running Ray head pod found." >&2
  exit 1
fi
echo "Found head pod: ${HEAD_POD_NAME}"

echo "[$(date)] ========== Checking the recipe in the NeMo RL ${NEMO_RL_VERSION} image =========="
if ! kubectl exec "${HEAD_POD_NAME}" -c ray-head -- test -f "/opt/nemo-rl/${NEMO_RL_RECIPE}"; then
  echo "Error: Recipe ${NEMO_RL_RECIPE} does not exist in nvcr.io/nvidia/nemo-rl:${NEMO_RL_VERSION}." >&2
  exit 1
fi

WANDB_ENABLED="False"
if [[ -n "${WANDB_API_KEY}" && "${WANDB_API_KEY}" != "YOUR_WANDB_API_KEY" ]]; then
  WANDB_ENABLED="True"
fi

echo "[$(date)] ========== Submitting the job for ${MODEL_ID} (log: ${LOG_FILE}) =========="
exec > >(tee "${LOG_FILE}") 2>&1

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_job_submit]
kubectl exec -i "${HEAD_POD_NAME}" -c ray-head -- bash -s <<EOF
set -euo pipefail
cd /opt/nemo-rl
export WANDB_API_KEY="${WANDB_API_KEY}"
export HF_TOKEN="${HF_TOKEN}"
uv run examples/run_grpo.py \
  --config "${NEMO_RL_RECIPE}" \
  policy.model_name="${MODEL_ID}" \
  policy.tokenizer.name="${MODEL_ID}" \
  cluster.num_nodes="${NUM_GPU_NODES}" \
  cluster.gpus_per_node=8 \
  grpo.max_num_steps="${GRPO_MAX_STEPS}" \
  checkpointing.checkpoint_dir="/data/${RUN_NAME}" \
  logger.log_dir="/data/${RUN_NAME}/logs" \
  logger.tensorboard_enabled=True \
  logger.wandb_enabled="${WANDB_ENABLED}" \
  logger.wandb.name="${RUN_NAME}"
EOF
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_job_submit]

echo "[$(date)] ========== Job finished =========="
