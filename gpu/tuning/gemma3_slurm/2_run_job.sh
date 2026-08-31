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
echo "[$(date)] Finding login node for cluster ${CLUSTER_NAME}..."

# [START hypercomputer_gpu_tune_gemma3_slurm_find_login_node]
LOGIN_NODE="$(gcloud compute instances list \
                --project="${PROJECT_ID}" \
                --filter="labels.ghpc_deployment='${CLUSTER_NAME}' AND labels.slurm_instance_role='login'" \
                --format="value(name)" | head -n 1)"
# [END hypercomputer_gpu_tune_gemma3_slurm_find_login_node]

if [ -z "${LOGIN_NODE}" ]; then
  echo "Error: Could not find login node for cluster ${CLUSTER_NAME}." >&2
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

FIREWALL_EXISTS=$(gcloud compute firewall-rules list \
  --project="${PROJECT_ID:-}" \
  --filter="name=${FIREWALL_RULE_NAME} AND network=${CLUSTER_NETWORK}" \
  --format="value(name)" 2>/dev/null || echo "")

if [ -z "${FIREWALL_EXISTS}" ]; then
  echo "Creating missing firewall rule '${FIREWALL_RULE_NAME}' for network ${CLUSTER_NETWORK}..."
  gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT_ID:-}" \
    --network="${CLUSTER_NETWORK}" \
    --direction=INGRESS \
    --action=allow \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP) for ${CLUSTER_NETWORK}"
  echo "Firewall rule created successfully."
else
  echo "Firewall rule '${FIREWALL_RULE_NAME}' already exists for this network. Skipping creation."
fi

# 2. SCP scripts to login node
echo "[$(date)] Uploading workload scripts to login node..."
# [START hypercomputer_gpu_tune_gemma3_slurm_scp_scripts]
gcloud compute scp \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  ./install_environment.sh \
  ./requirements.txt \
  ./submit.slurm \
  ./accelerate_config.yaml \
  ./train.py \
  "${LOGIN_NODE}":~/
# [END hypercomputer_gpu_tune_gemma3_slurm_scp_scripts]

# 3. Connect and run environment setup & submit job
echo "[$(date)] Running environment setup and submitting Slurm job on login node..."

# We run ssh and capture stdout to get the Job ID.
# Since we need to run multiple commands, we chain them.
SSH_CMD="export HF_TOKEN='${HF_TOKEN}' && export HUGGING_FACE_TOKEN='${HF_TOKEN}' && chmod +x install_environment.sh && ./install_environment.sh && sbatch submit.slurm"

SSH_OUTPUT="$(gcloud compute ssh "${LOGIN_NODE}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --command="${SSH_CMD}")"

echo "${SSH_OUTPUT}"
JOB_ID=$(echo "${SSH_OUTPUT}" | grep -oP 'Submitted batch job \K\d+')

if [ -z "${JOB_ID}" ]; then
  echo "Error: Failed to submit Slurm job or parse Job ID." >&2
  exit 1
fi
echo "Successfully submitted Slurm job ID: ${JOB_ID}"

echo "[$(date)] ==================== Waiting for the job to finish ===================="

# 4. Poll job status until it finishes
echo "[$(date)] Monitoring Slurm job ${JOB_ID}..."
MAX_RETRIES=240
retry_count=0

while true; do
  # Get job state (%T) and reason (%r) directly
  STATUS_LINE="$(gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="squeue -h -j ${JOB_ID} -o '%T %r'" 2>/dev/null || true)"

  if [ -z "${STATUS_LINE}" ]; then
    echo "[$(date)] Job ${JOB_ID} completed or left squeue."
    break
  fi

  STATE="$(echo "${STATUS_LINE}" | awk '{print $1}')"
  REASON="$(echo "${STATUS_LINE}" | cut -d' ' -f2-)"

  echo "[$(date)] Job ${JOB_ID} State: ${STATE} | Reason: ${REASON} (${retry_count}/${MAX_RETRIES})"

  # Fail immediately on fatal Slurm states
  if [[ "${STATE}" =~ ^(FAILED|CANCELLED|BOOT_FAIL|NODE_FAIL|OUT_OF_MEMORY)$ ]]; then
    echo "Slurm job ${JOB_ID} failed with state ${STATE}." >&2
    exit 1
  fi

  if [ ${retry_count} -ge ${MAX_RETRIES} ]; then
    echo "Timeout waiting for Slurm job ${JOB_ID} to complete." >&2
    exit 1
  fi

  sleep 30
  retry_count=$((retry_count+1))
done

echo "[$(date)] Slurm job ${JOB_ID} has finished execution."
echo "[$(date)] ==================== Workload Execution Complete ===================="
