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

declare -r LOGIN_READY_TIMEOUT=1200
declare -r JOB_TIMEOUT=7200
declare -r POLL_INTERVAL=30
declare -r SSH_TIMEOUT=300
declare -r SETUP_TIMEOUT=1800
declare -r JOB_ID_FILE="slurm_job_id.txt"

login_ssh() {
  local limit="${2:-${SSH_TIMEOUT}}"
  timeout "${limit}" gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --quiet \
    --ssh-flag="-o ConnectTimeout=30" \
    --ssh-flag="-o ServerAliveInterval=30" \
    --ssh-flag="-o ServerAliveCountMax=4" \
    --command="$1" </dev/null
}

echo "[$(date)] ==================== Starting Workload Execution ===================="

# 1. Identify login node
echo "[$(date)] Finding login node for cluster ${CLUSTER_NAME}..."

# [START hypercomputer_gpu_tune_gemma4_slurm_find_login_node]
LOGIN_NODE="$(gcloud compute instances list \
                --project="${PROJECT_ID}" \
                --filter="labels.ghpc_deployment='${CLUSTER_NAME}' AND labels.slurm_instance_role='login'" \
                --format="value(name)" | head -n 1)"
# [END hypercomputer_gpu_tune_gemma4_slurm_find_login_node]

if [ -z "${LOGIN_NODE}" ]; then
  echo "Error: Could not find login node for cluster ${CLUSTER_NAME}." >&2
  exit 1
fi
echo "Found login node: ${LOGIN_NODE}"

echo "[$(date)] Waiting for the login node to finish its setup (up to ${LOGIN_READY_TIMEOUT}s)..."
deadline=$((SECONDS + LOGIN_READY_TIMEOUT))
until login_ssh "findmnt -n /home > /dev/null && sinfo -h > /dev/null" 120 &>/dev/null; do
  if (( SECONDS >= deadline )); then
    echo "Timeout waiting for login node ${LOGIN_NODE} to finish its setup." >&2
    login_ssh "findmnt /home; sinfo; sudo journalctl -u google-startup-scripts --no-pager | tail -n 50" || true
    exit 1
  fi
  echo "[$(date)] Login node not ready yet, retrying in ${POLL_INTERVAL}s..."
  sleep "${POLL_INTERVAL}"
done
login_ssh "sinfo" || true

# 2. SCP scripts to login node
echo "[$(date)] Uploading workload scripts to login node..."
# [START hypercomputer_gpu_tune_gemma4_slurm_scp_scripts]
timeout 600 gcloud compute scp \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --quiet \
  ./install_environment.sh \
  ./requirements.txt \
  ./submit.slurm \
  ./accelerate_config.yaml \
  ./train.py \
  "${LOGIN_NODE}":~/ </dev/null
# [END hypercomputer_gpu_tune_gemma4_slurm_scp_scripts]

# 3. Connect and run environment setup & submit job
echo "[$(date)] Running environment setup and submitting Slurm job on login node..."

SSH_CMD="export HF_TOKEN='${HF_TOKEN}' && export HUGGING_FACE_TOKEN='${HF_TOKEN}' && export MODEL_ID='${MODEL_ID}' && chmod +x install_environment.sh && ./install_environment.sh && sbatch --nodes='${NUM_NODES}' submit.slurm"

SSH_OUTPUT="$(login_ssh "${SSH_CMD}" "${SETUP_TIMEOUT}")"

echo "${SSH_OUTPUT}"
JOB_ID="$(echo "${SSH_OUTPUT}" | grep -oP 'Submitted batch job \K\d+' || true)"

if [ -z "${JOB_ID}" ]; then
  echo "Error: Failed to submit Slurm job or parse Job ID." >&2
  exit 1
fi
echo "${JOB_ID}" > "${JOB_ID_FILE}"
echo "Successfully submitted Slurm job ID: ${JOB_ID}"

echo "[$(date)] ==================== Waiting for the job to finish ===================="

# 4. Poll job status until it finishes
echo "[$(date)] Monitoring Slurm job ${JOB_ID} (up to ${JOB_TIMEOUT}s)..."
deadline=$((SECONDS + JOB_TIMEOUT))

while true; do
  STATUS_OUTPUT="$(login_ssh "squeue -h -j ${JOB_ID} -o '%T %r' 2>/dev/null; echo SSH_OK" 2>/dev/null || true)"

  if ! grep -q "SSH_OK" <<< "${STATUS_OUTPUT}"; then
    echo "[$(date)] Could not reach the login node, retrying..."
  else
    STATUS_LINE="$(grep -v "SSH_OK" <<< "${STATUS_OUTPUT}" | head -n 1 || true)"
    if [ -z "${STATUS_LINE}" ]; then
      echo "[$(date)] Job ${JOB_ID} left the queue."
      break
    fi

    STATE="$(awk '{print $1}' <<< "${STATUS_LINE}")"
    REASON="$(cut -d' ' -f2- <<< "${STATUS_LINE}")"
    echo "[$(date)] Job ${JOB_ID} State: ${STATE} | Reason: ${REASON}"

    if [[ "${STATE}" == "COMPLETED" ]]; then
      break
    fi

    # Fail immediately on fatal Slurm states
    if [[ "${STATE}" =~ ^(FAILED|CANCELLED|BOOT_FAIL|NODE_FAIL|OUT_OF_MEMORY|TIMEOUT|PREEMPTED|DEADLINE)$ ]]; then
      echo "Slurm job ${JOB_ID} failed with state ${STATE}." >&2
      login_ssh "tail -n 100 slurm-${JOB_ID}.out slurm-${JOB_ID}.err" || true
      exit 1
    fi
  fi

  if (( SECONDS >= deadline )); then
    echo "Timeout waiting for Slurm job ${JOB_ID} to complete. Cancelling it." >&2
    login_ssh "sinfo -R; scancel ${JOB_ID}; tail -n 100 slurm-${JOB_ID}.out slurm-${JOB_ID}.err" || true
    exit 1
  fi

  sleep "${POLL_INTERVAL}"
done

FINAL_STATE="$(login_ssh "sacct -n -X -P -j ${JOB_ID} -o State" 2>/dev/null | head -n 1 | awk '{print $1}' || true)"
echo "[$(date)] Slurm job ${JOB_ID} final state: ${FINAL_STATE:-unknown}"
if [ -n "${FINAL_STATE}" ] && [ "${FINAL_STATE}" != "COMPLETED" ]; then
  echo "Slurm job ${JOB_ID} did not complete successfully." >&2
  login_ssh "tail -n 100 slurm-${JOB_ID}.out slurm-${JOB_ID}.err" || true
  exit 1
fi

echo "[$(date)] Slurm job ${JOB_ID} has finished execution."
echo "[$(date)] ==================== Workload Execution Complete ===================="
