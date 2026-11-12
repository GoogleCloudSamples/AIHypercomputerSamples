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

declare -r JOB_ID_FILE="slurm_job_id.txt"
declare -r LOG_FILE="slurm_job_logs.txt"
declare -r FINAL_MODEL_DIR="gemma4-text-to-sql-finetuned"

login_ssh() {
  timeout 300 gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --quiet \
    --ssh-flag="-o ConnectTimeout=30" \
    --ssh-flag="-o ServerAliveInterval=30" \
    --ssh-flag="-o ServerAliveCountMax=4" \
    --command="$1" </dev/null
}

fail() {
  echo "[$(date)] Validation failed: $1" >&2
  exit 1
}

echo "[$(date)] ==================== Starting Validation... ===================="

# 1. Identify login node
echo "[$(date)] Finding login node for cluster ${CLUSTER_NAME}..."
LOGIN_NODE="$(gcloud compute instances list \
                --project="${PROJECT_ID}" \
                --filter="labels.ghpc_deployment='${CLUSTER_NAME}' AND labels.slurm_instance_role='login'" \
                --format="value(name)" | head -n 1)"

if [ -z "${LOGIN_NODE}" ]; then
  fail "could not find the login node for cluster ${CLUSTER_NAME}."
fi
echo "Found login node: ${LOGIN_NODE}"

# 2. Identify the job
if [ -s "${JOB_ID_FILE}" ]; then
  JOB_ID="$(cat "${JOB_ID_FILE}")"
else
  echo "${JOB_ID_FILE} not found, using the most recent Slurm log on the login node."
  JOB_ID="$(login_ssh "ls -t slurm-*.out 2>/dev/null | head -n 1" | grep -oP 'slurm-\K\d+' || true)"
fi
if [ -z "${JOB_ID}" ]; then
  fail "could not determine the Slurm job ID."
fi
echo "Validating Slurm job ${JOB_ID}"

# 3. Fetch the job logs and accounting data from the login node
echo "[$(date)] Fetching Slurm output and error logs from login node..."
login_ssh "cat slurm-${JOB_ID}.out slurm-${JOB_ID}.err" > "${LOG_FILE}" || true

echo "--------------------------------------------------------------------------------"
echo "Captured Slurm Logs:"
echo "--------------------------------------------------------------------------------"
cat "${LOG_FILE}"
echo "--------------------------------------------------------------------------------"
echo "Slurm accounting:"
login_ssh "sacct -j ${JOB_ID} -o JobID,JobName%30,State,ExitCode,Elapsed,NodeList%40" || true
echo "--------------------------------------------------------------------------------"

# 4. Assert successful training
FINAL_STATE="$(login_ssh "sacct -n -X -P -j ${JOB_ID} -o State" 2>/dev/null | head -n 1 | awk '{print $1}' || true)"
if [ -n "${FINAL_STATE}" ] && [ "${FINAL_STATE}" != "COMPLETED" ]; then
  fail "Slurm job ${JOB_ID} ended in state ${FINAL_STATE}."
fi

echo "Checking for successful training indicators..."
grep -q "Training finished." "${LOG_FILE}" || fail "'Training finished.' not found in logs."
grep -q "Saving final model to" "${LOG_FILE}" || fail "'Saving final model to' not found in logs."

# 5. Assert that the LoRA adapter was saved
echo "[$(date)] Checking the saved adapter in ${FINAL_MODEL_DIR}..."
CHECK_CMD="$(cat <<EOF
ls -la ${FINAL_MODEL_DIR} && cat ${FINAL_MODEL_DIR}/adapter_config.json && echo && python3 -c '
import json, struct, sys
with open(sys.argv[1], "rb") as f:
    header_size = struct.unpack("<Q", f.read(8))[0]
    keys = [k for k in json.loads(f.read(header_size)) if k != "__metadata__"]
lora = [k for k in keys if "language_model" in k and "lora_" in k]
towers = [k for k in keys if "vision" in k or "audio" in k]
print(f"lora_tensors={len(lora)} tower_tensors={len(towers)}")
' ${FINAL_MODEL_DIR}/adapter_model.safetensors
EOF
)"
ADAPTER_OUTPUT="$(login_ssh "${CHECK_CMD}" || true)"
echo "${ADAPTER_OUTPUT}"

LORA_TENSORS="$(grep -oP 'lora_tensors=\K\d+' <<< "${ADAPTER_OUTPUT}" || true)"
TOWER_TENSORS="$(grep -oP 'tower_tensors=\K\d+' <<< "${ADAPTER_OUTPUT}" || true)"
if [ -z "${LORA_TENSORS}" ] || [ "${LORA_TENSORS}" -eq 0 ]; then
  fail "no LoRA language model tensors found in ${FINAL_MODEL_DIR}/adapter_model.safetensors."
fi
if [ "${TOWER_TENSORS:-1}" -ne 0 ]; then
  fail "unexpected vision or audio tensors in ${FINAL_MODEL_DIR}/adapter_model.safetensors."
fi

echo "[$(date)] Validation passed: job ${JOB_ID} completed and saved ${LORA_TENSORS} LoRA tensors."
echo "[$(date)] ==================== Validation Complete. ===================="
