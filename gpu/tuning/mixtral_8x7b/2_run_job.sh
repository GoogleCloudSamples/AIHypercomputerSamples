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

# 1. Identify login node
echo "[$(date)] Finding login node for cluster ${DEPLOYMENT_NAME}..."

# Automatically retrieve the username
CURRENT_USER="${USER:-$(whoami)}"

# Build a secure filter:
# Search for a machine that has 'login' in its name and the current user's name
# [START hypercomputer_gpu_tune_mixtral_slurm_download_login_node]
LOGIN_NODE="$(gcloud compute instances list \
                --project="${PROJECT_ID}" \
                --filter="labels.ghpc_deployment='${DEPLOYMENT_NAME}' AND labels.slurm_instance_role='login'" \
                --format="value(name)" | head -n 1)"
# [END hypercomputer_gpu_tune_mixtral_slurm_download_login_node]

if [ -z "${LOGIN_NODE}" ]; then
  echo "Error: Could not find login node for user '${CURRENT_USER}' containing 'login'." >&2
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
    gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
      --project="${PROJECT_ID:-}" \
      --network="${CLUSTER_NETWORK}" \
      --direction=INGRESS \
      --action=allow \
      --rules=tcp:22 \
      --source-ranges=35.235.240.0/20 \
      --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP) for ${CLUSTER_NETWORK}" || true
    echo "Firewall rule created successfully."
  else
    echo "Firewall rule '${FIREWALL_RULE_NAME}' already exists for this network. Skipping creation."
  fi
}

ensure_iap_firewall

# Wait for Slurm controller and login node startup scripts to finish
echo "[$(date)] Waiting for Slurm to be ready on ${LOGIN_NODE}..."
for i in {1..30}; do
  ensure_iap_firewall
  if gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="sinfo >/dev/null 2>&1" 2>/dev/null; then
    echo "Slurm is ready!"
    break
  fi
  if [ "${i}" -eq 30 ]; then
    echo "Error: Timed out waiting for Slurm to become ready on ${LOGIN_NODE}." >&2
    exit 1
  fi
  echo "Slurm not ready yet. Waiting 15 seconds... (${i}/30)"
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
      echo "Error: Timeout waiting for ${label} (job ${job_id}) to complete." >&2
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
      "$@" "${LOGIN_NODE}":~/; then
      return 0
    fi
    echo "Warning: SCP to ${LOGIN_NODE} failed (attempt ${attempt}/5). Retrying in 10s..." >&2
    sleep 10
  done
  echo "Error: SCP to ${LOGIN_NODE} failed after 5 attempts." >&2
  return 1
}

# Build transient Slurm batch wrappers so the unmodified install_environment.sh
# and train-mixtral.sh can run against node-local NVMe (/mnt/localssd) without
# incurring cross-region Managed Lustre small-file metadata latency.
WRAPPER_DIR=$(mktemp -d)
trap 'rm -rf "${WRAPPER_DIR}"' EXIT

cat <<'EOF' > "${WRAPPER_DIR}/.run_env_setup.sbatch"
#!/bin/bash
#SBATCH --job-name=env-setup
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --partition=a4high
#SBATCH --output=env-setup-%j.out
#SBATCH --error=env-setup-%j.err
set -eo pipefail

REAL_HOME="${HOME}"
STAGE_HOME="/mnt/localssd/mixtral_stage_home"
WORK_TMP="/mnt/localssd/env_setup_${SLURM_JOB_ID:-$$}"
VENV_ARCHIVE="${REAL_HOME}/.venv/venv-fsdp.tar"

if [ ! -d /mnt/localssd ] || [ ! -w /mnt/localssd ]; then
  echo "ERROR: Local SSD directory /mnt/localssd is not available or writable." >&2
  exit 1
fi

cleanup() {
  rm -rf "${STAGE_HOME}" "${WORK_TMP}" "${VENV_ARCHIVE}.tmp"
}
trap cleanup EXIT

rm -rf "${STAGE_HOME}" "${WORK_TMP}"
mkdir -p "${STAGE_HOME}" \
  "${WORK_TMP}/pip_cache" \
  "${WORK_TMP}/hf_cache" \
  "${WORK_TMP}/tmp" \
  "${WORK_TMP}/torch_extensions"

export PIP_NO_CACHE_DIR=1
export PIP_CACHE_DIR="${WORK_TMP}/pip_cache"
export HF_HOME="${WORK_TMP}/hf_cache"
export TMPDIR="${WORK_TMP}/tmp"
export TORCH_EXTENSIONS_DIR="${WORK_TMP}/torch_extensions"

cd "${SLURM_SUBMIT_DIR}"
HOME="${STAGE_HOME}" bash ./install_environment.sh

# Store the virtual environment as a single streaming tarball on shared storage.
mkdir -p "${REAL_HOME}/.venv"
tar -cf "${VENV_ARCHIVE}.tmp" -C "${STAGE_HOME}" .venv
mv -f "${VENV_ARCHIVE}.tmp" "${VENV_ARCHIVE}"

# Copy model weights to shared storage, excluding the HF download cache/locks.
mkdir -p "${REAL_HOME}/Mixtral-8x7B-v0.1"
rsync -a --exclude='.cache' "${STAGE_HOME}/Mixtral-8x7B-v0.1/" "${REAL_HOME}/Mixtral-8x7B-v0.1/"
EOF

cat <<'EOF' > "${WRAPPER_DIR}/.run_train.sbatch"
#!/bin/bash
#SBATCH --job-name=mixtral-fsdp
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --partition=a4high
#SBATCH --output=mixtral-%j.out
#SBATCH --error=mixtral-%j.err
set -eo pipefail

REAL_HOME="${HOME}"
STAGE_HOME="/mnt/localssd/mixtral_stage_home"
WORK_TMP="/mnt/localssd/train_tmp_${SLURM_JOB_ID:-$$}"
VENV_ARCHIVE="${REAL_HOME}/.venv/venv-fsdp.tar"

cleanup() {
  HOME="${REAL_HOME}" srun --ntasks="${SLURM_NNODES}" --ntasks-per-node=1 bash -c "
    rm -f '${STAGE_HOME}/Mixtral-8x7B-v0.1' '${STAGE_HOME}/outputs'
    rm -rf '${STAGE_HOME}' '${WORK_TMP}'
  " || true
}
trap cleanup EXIT

mkdir -p "${REAL_HOME}/outputs"

# Unpack the archived venv once on each compute node and symlink the shared
# model and outputs directories so the unmodified train-mixtral.sh can run with
# HOME pointed at local NVMe.
srun --ntasks="${SLURM_NNODES}" --ntasks-per-node=1 bash -c "
  set -e
  rm -f '${STAGE_HOME}/Mixtral-8x7B-v0.1' '${STAGE_HOME}/outputs'
  rm -rf '${STAGE_HOME}' '${WORK_TMP}'
  mkdir -p '${STAGE_HOME}' '${WORK_TMP}/triton_cache' '${WORK_TMP}/tmp'
  tar -xf '${VENV_ARCHIVE}' -C '${STAGE_HOME}'
  ln -sfn '${REAL_HOME}/Mixtral-8x7B-v0.1' '${STAGE_HOME}/Mixtral-8x7B-v0.1'
  ln -sfn '${REAL_HOME}/outputs' '${STAGE_HOME}/outputs'
"

export HOME="${STAGE_HOME}"
export TRITON_CACHE_DIR="${WORK_TMP}/triton_cache"
export TMPDIR="${WORK_TMP}/tmp"

cd "${SLURM_SUBMIT_DIR}"
bash "${SLURM_SUBMIT_DIR}/train-mixtral.sh"
EOF

chmod +x "${WRAPPER_DIR}/.run_env_setup.sbatch" "${WRAPPER_DIR}/.run_train.sbatch"
scp_to_login_with_retry "${WRAPPER_DIR}/.run_env_setup.sbatch" "${WRAPPER_DIR}/.run_train.sbatch"

# 3. Submit environment setup job via sbatch (avoid holding one long-lived IAP SSH tunnel)
echo "[$(date)] Submitting environment setup job (install_environment.sh) on login node..."
ENV_SUBMIT_CMD="chmod +x install_environment.sh && \
export HF_TOKEN='${HF_TOKEN}' && \
sbatch --export=ALL ~/.run_env_setup.sbatch"

ENV_OUTPUT=$(ssh_login_with_retry "${ENV_SUBMIT_CMD}")
echo "${ENV_OUTPUT}"

ENV_JOB_ID=$(echo "${ENV_OUTPUT}" | grep -oP 'Submitted batch job \K\d+' || true)
if [ -z "${ENV_JOB_ID}" ]; then
  echo "Error: Failed to submit env-setup Slurm job or parse Job ID." >&2
  exit 1
fi
echo "Successfully submitted env-setup Slurm job ID: ${ENV_JOB_ID}"

poll_slurm_job "${ENV_JOB_ID}" "env-setup" 240

# Verify environment setup completed successfully before submitting training
ENV_STATE=""
for attempt in {1..5}; do
  ensure_iap_firewall
  ENV_STATE=$(gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="sacct -j ${ENV_JOB_ID} -X -n -o State | head -n 1 | xargs" 2>/dev/null || echo "")
  if [ -n "${ENV_STATE}" ] && [ "${ENV_STATE}" != "PENDING" ] && [ "${ENV_STATE}" != "RUNNING" ] && [ "${ENV_STATE}" != "COMPLETING" ]; then
    break
  fi
  sleep 5
done

echo "[$(date)] env-setup job ${ENV_JOB_ID} finished with state: ${ENV_STATE:-UNKNOWN}"
if [ -n "${ENV_STATE}" ] && [ "${ENV_STATE}" != "COMPLETED" ]; then
  echo "Error: env-setup job ${ENV_JOB_ID} failed with state '${ENV_STATE}'. Last logs:" >&2
  ensure_iap_firewall
  gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="tail -n 100 ~/env-setup-${ENV_JOB_ID}.out ~/env-setup-${ENV_JOB_ID}.err 2>/dev/null || true" || true
  exit 1
fi

ARTIFACT_CHECK=$(ssh_login_with_retry "if [ -s ~/.venv/venv-fsdp.tar ] && [ -d ~/Mixtral-8x7B-v0.1 ]; then echo MIXTRAL_ARTIFACTS_OK; else echo MIXTRAL_ARTIFACTS_MISSING; fi")
if ! echo "${ARTIFACT_CHECK}" | grep -q "MIXTRAL_ARTIFACTS_OK"; then
  echo "Error: Expected environment archive (~/.venv/venv-fsdp.tar) or model directory (~/Mixtral-8x7B-v0.1) is missing. Last logs:" >&2
  ensure_iap_firewall
  gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="tail -n 100 ~/env-setup-${ENV_JOB_ID}.out ~/env-setup-${ENV_JOB_ID}.err 2>/dev/null || true" || true
  exit 1
fi

# 4. Submit training job
echo "[$(date)] Submitting training job (train-mixtral.sh) on login node..."
TRAIN_OUTPUT=$(ssh_login_with_retry "sbatch ~/.run_train.sbatch")
echo "${TRAIN_OUTPUT}"

JOB_ID=$(echo "${TRAIN_OUTPUT}" | grep -oP 'Submitted batch job \K\d+' || true)
if [ -z "${JOB_ID}" ]; then
  echo "Error: Failed to submit training Slurm job or parse Job ID." >&2
  exit 1
fi
echo "Successfully submitted training Slurm job ID: ${JOB_ID}"

# 5. Poll training job status until it finishes
poll_slurm_job "${JOB_ID}" "training" 240

echo "[$(date)] Slurm job ${JOB_ID} has finished execution."
echo "[$(date)] ==================== Workload Execution Complete ===================="
