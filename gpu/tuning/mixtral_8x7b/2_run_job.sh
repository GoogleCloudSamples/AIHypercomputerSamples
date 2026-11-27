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

echo "[$(date)] ==================== Starting Workload Execution ===================="

# Expire gcloud OS Login SSH keys to avoid hitting the 32 KiB profile limit (refreshed on each call)
ssh_key_expire_after="1d"

# 1. Identify login node
echo "[$(date)] Finding login node for cluster ${DEPLOYMENT_NAME}..."

# Find the login node by its cluster deployment and Slurm role labels
# [START hypercomputer_gpu_tune_mixtral_slurm_download_login_node]
LOGIN_NODE="$(gcloud compute instances list \
                --project="${PROJECT_ID}" \
                --filter="labels.ghpc_deployment='${DEPLOYMENT_NAME}' AND labels.slurm_instance_role='login'" \
                --format="value(name)" | head -n 1)"
# [END hypercomputer_gpu_tune_mixtral_slurm_download_login_node]

if [ -z "${LOGIN_NODE}" ]; then
  echo "Error: Could not find login node for cluster '${DEPLOYMENT_NAME}'." >&2
  echo "Verify that your cluster deployment succeeded and the login node is running." >&2
  exit 1
fi
echo "Found login node: ${LOGIN_NODE}"

# Dynamic detection of the VPC network and configuration of the IAP Firewall
echo "[$(date)] Identifying VPC Network and ensuring IAP firewall rule exists..."

# Retrieve the full URI of the network where the Login Node is located
VPC_NETWORK_URI=$(gcloud compute instances describe "${LOGIN_NODE}" \
  --project="${PROJECT_ID:-}" \
  --zone="${ZONE:-}" \
  --format="value(networkInterfaces[0].network)" 2>/dev/null || echo "")

CLUSTER_NETWORK=$(basename "${VPC_NETWORK_URI}")

if [ -z "${CLUSTER_NETWORK}" ]; then
  echo "Error: Could not determine VPC network for instance ${LOGIN_NODE}." >&2
  exit 1
fi
echo "Detected VPC Network: ${CLUSTER_NETWORK}"

FIREWALL_RULE_NAME="allow-ssh-from-iap-${CLUSTER_NETWORK}"

ensure_iap_firewall() {
  local firewall_exists
  firewall_exists=$(gcloud compute firewall-rules list \
    --project="${PROJECT_ID:-}" \
    --filter="name=${FIREWALL_RULE_NAME} AND network=${CLUSTER_NETWORK}" \
    --format="value(name)" 2>/dev/null || echo "")

  if [ -z "${firewall_exists}" ]; then
    echo "Creating missing firewall rule '${FIREWALL_RULE_NAME}' for network ${CLUSTER_NETWORK}..."
    if gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
      --project="${PROJECT_ID:-}" \
      --network="${CLUSTER_NETWORK}" \
      --direction=INGRESS \
      --action=allow \
      --rules=tcp:22 \
      --source-ranges=35.235.240.0/20 \
      --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP) for ${CLUSTER_NETWORK}"; then
      echo "Firewall rule created successfully."
    else
      echo "Warning: Failed to create firewall rule '${FIREWALL_RULE_NAME}'." >&2
    fi
  fi
}

ensure_iap_firewall

# Wait for Slurm controller and login node startup scripts to finish
echo "[$(date)] Waiting for Slurm to be ready on ${LOGIN_NODE}..."
SLURM_READY_ERR=""
for i in {1..60}; do
  ensure_iap_firewall
  # Keep the SSH/sinfo error output so a timeout can explain what failed.
  if SLURM_READY_ERR=$(gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --ssh-key-expire-after="${ssh_key_expire_after}" \
    --command="sinfo >/dev/null" 2>&1 >/dev/null); then
    echo "Slurm is ready!"
    break
  fi
  if [ "${i}" -eq 60 ]; then
    echo "Error: Timed out waiting for Slurm to become ready on ${LOGIN_NODE}." >&2
    echo "--- Last SSH/sinfo error ---" >&2
    echo "${SLURM_READY_ERR}" | tail -n 20 >&2
    echo "--- Effective firewall rules on network ${CLUSTER_NETWORK} (incl. org policies) ---" >&2
    gcloud compute networks get-effective-firewalls "${CLUSTER_NETWORK}" \
      --project="${PROJECT_ID}" >&2 || true
    echo "--- Last 100 lines of ${LOGIN_NODE} serial console ---" >&2
    gcloud compute instances get-serial-port-output "${LOGIN_NODE}" \
      --project="${PROJECT_ID}" \
      --zone="${ZONE}" 2>/dev/null | tail -n 100 >&2 || true
    exit 1
  fi
  echo "Slurm not ready yet. Waiting 15 seconds... (${i}/60)"
  sleep 15
done

# 2. Transfer the submission script to the Login Node
echo "[$(date)] Uploading workload scripts to login node..."
ensure_iap_firewall
# [START hypercomputer_gpu_tune_mixtral_slurm_transfer_scripts]
gcloud compute scp \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  ./install_environment.sh \
  ./requirements-fsdp.txt \
  ./train-mixtral.py \
  ./train-mixtral.sh \
  "${LOGIN_NODE}":~/
# [END hypercomputer_gpu_tune_mixtral_slurm_transfer_scripts]

ssh_login_with_retry() {
  local cmd="$1"
  local output=""
  for attempt in {1..5}; do
    ensure_iap_firewall >&2
    if output=$(gcloud compute ssh "${LOGIN_NODE}" \
      --project="${PROJECT_ID}" \
      --zone="${ZONE}" \
      --tunnel-through-iap \
      --ssh-key-expire-after="${ssh_key_expire_after}" \
      --command="${cmd}"); then
      printf '%s\n' "${output}"
      return 0
    fi
    echo "Warning: SSH command to ${LOGIN_NODE} failed (attempt ${attempt}/5). Retrying in 10s..." >&2
    sleep 10
  done
  echo "Error: SSH command to ${LOGIN_NODE} failed after 5 attempts." >&2
  return 1
}

# Print the last lines of a Slurm job's .out/.err files from the login node.
print_job_logs() {
  local job_id="$1"
  ssh_login_with_retry "tail -n 100 ~/*-${job_id}.out ~/*-${job_id}.err 2>/dev/null || true" || true
}

# Print a Slurm job's final state, waiting briefly for accounting to settle.
get_job_state() {
  local job_id="$1"
  local state=""
  for attempt in {1..5}; do
    state=$(ssh_login_with_retry "sacct -j ${job_id} -X -n -o State | head -n 1 | xargs" 2>/dev/null || echo "")
    state="${state%% *}" # e.g. "CANCELLED by 123" -> "CANCELLED"
    case "${state}" in
      ""|PENDING|RUNNING|COMPLETING) sleep 5 ;;
      *) break ;;
    esac
  done
  printf '%s\n' "${state:-UNKNOWN}"
}

# Exit with an error (and print job logs) unless the job state is COMPLETED.
check_job_completed() {
  local job_id="$1"
  local label="$2"
  local show_logs="${3:-true}"
  local state
  state=$(get_job_state "${job_id}")
  echo "[$(date)] ${label} job ${job_id} finished with state: ${state}"
  if [ "${state}" != "COMPLETED" ]; then
    echo "Error: ${label} job ${job_id} did not complete successfully (state: '${state}')." >&2
    if [ "${show_logs}" = "true" ]; then
      echo "Last logs:" >&2
      print_job_logs "${job_id}"
    fi
    exit 1
  fi
}

poll_slurm_job() {
  local job_id="$1"
  local label="$2"
  local limit="${3:-240}" # 2 hours maximum polling (30s * 240)
  local count=0
  local squeue_output=""

  echo "[$(date)] Monitoring ${label} (Slurm job ${job_id})..."
  while true; do
    ensure_iap_firewall
    if squeue_output=$(gcloud compute ssh "${LOGIN_NODE}" \
      --project="${PROJECT_ID}" \
      --zone="${ZONE}" \
      --tunnel-through-iap \
      --ssh-key-expire-after="${ssh_key_expire_after}" \
      --command="squeue -h -j ${job_id} -o '%i %T' 2>&1" 2>/dev/null); then
      if ! echo "${squeue_output}" | grep -qE "^[[:space:]]*${job_id}([[:space:]]|$)"; then
        break
      fi
    elif echo "${squeue_output}" | grep -q "Invalid job id specified"; then
      break
    else
      echo "Warning: SSH/squeue failed while polling ${label} (job ${job_id}). Retrying..."
    fi
    if [ "${count}" -ge "${limit}" ]; then
      echo "Error: Timeout waiting for ${label} (job ${job_id}) to complete. Last logs:" >&2
      print_job_logs "${job_id}"
      exit 1
    fi
    echo "${label} (job ${job_id}) status: ${squeue_output:-unknown}. Waiting 30 seconds... (${count}/${limit})"
    sleep 30
    count=$((count+1))
  done
}

scp_to_login_with_retry() {
  for attempt in {1..5}; do
    ensure_iap_firewall >&2
    if gcloud compute scp \
      --project="${PROJECT_ID}" \
      --zone="${ZONE}" \
      --tunnel-through-iap \
      --ssh-key-expire-after="${ssh_key_expire_after}" \
      "$@" "${LOGIN_NODE}":~/; then
      return 0
    fi
    echo "Warning: SCP to ${LOGIN_NODE} failed (attempt ${attempt}/5). Retrying in 10s..." >&2
    sleep 10
  done
  echo "Error: SCP to ${LOGIN_NODE} failed after 5 attempts." >&2
  return 1
}

# Upload sbatch wrappers that stage setup/training on local NVMe to avoid cross-region Lustre latency
scp_to_login_with_retry ./env_setup.sbatch ./train.sbatch

# 3. Submit environment setup job via sbatch (avoid holding one long-lived IAP SSH tunnel)
echo "[$(date)] Submitting environment setup job (install_environment.sh) on login node..."
ENV_SUBMIT_CMD="chmod +x install_environment.sh && \
export HF_TOKEN='${HF_TOKEN}' && \
sbatch --export=ALL ~/env_setup.sbatch"

ENV_OUTPUT=$(ssh_login_with_retry "${ENV_SUBMIT_CMD}")
echo "${ENV_OUTPUT}"

ENV_JOB_ID=$(echo "${ENV_OUTPUT}" | grep -oP 'Submitted batch job \K\d+' || true)
if [ -z "${ENV_JOB_ID}" ]; then
  echo "Error: Failed to submit env-setup Slurm job or parse Job ID." >&2
  exit 1
fi
echo "Successfully submitted env-setup Slurm job ID: ${ENV_JOB_ID}"

poll_slurm_job "${ENV_JOB_ID}" "env-setup" "${ENV_SETUP_POLL_LIMIT:-360}"

# Verify environment setup completed successfully before submitting training
check_job_completed "${ENV_JOB_ID}" "env-setup"

ARTIFACT_CHECK=$(ssh_login_with_retry "if [ -s ~/.venv/venv-fsdp.tar ] && [ -d ~/Mixtral-8x7B-v0.1 ]; then echo MIXTRAL_ARTIFACTS_OK; else echo MIXTRAL_ARTIFACTS_MISSING; fi")
if ! echo "${ARTIFACT_CHECK}" | grep -q "MIXTRAL_ARTIFACTS_OK"; then
  echo "Error: Expected environment archive (~/.venv/venv-fsdp.tar) or model directory (~/Mixtral-8x7B-v0.1) is missing. Last logs:" >&2
  print_job_logs "${ENV_JOB_ID}"
  exit 1
fi

# 4. Submit training job
echo "[$(date)] Submitting training job (train-mixtral.sh) on login node..."
TRAIN_OUTPUT=$(ssh_login_with_retry "sbatch ~/train.sbatch")
echo "${TRAIN_OUTPUT}"

JOB_ID=$(echo "${TRAIN_OUTPUT}" | grep -oP 'Submitted batch job \K\d+' || true)
if [ -z "${JOB_ID}" ]; then
  echo "Error: Failed to submit training Slurm job or parse Job ID." >&2
  exit 1
fi
echo "Successfully submitted training Slurm job ID: ${JOB_ID}"

# 5. Poll training job status until it finishes
poll_slurm_job "${JOB_ID}" "training" "${TRAIN_POLL_LIMIT:-240}"

# 6. Surface the training job's summary and logs, then verify its final state.
# Leaving the queue only means the job ended, not that it succeeded.
ssh_login_with_retry "sacct -j ${JOB_ID} -o JobID,JobName,State,ExitCode,Elapsed,NodeList" 2>/dev/null || true
echo "[$(date)] Last training logs (job ${JOB_ID}):"
print_job_logs "${JOB_ID}"
check_job_completed "${JOB_ID}" "training" false

echo "[$(date)] ==================== Workload Execution Complete ===================="
