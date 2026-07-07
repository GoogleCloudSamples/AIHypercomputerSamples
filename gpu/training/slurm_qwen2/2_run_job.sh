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

# Automatically retrieve the username
CURRENT_USER="${USER:-$(whoami)}"

# Build a secure filter:
# Search for a machine that has 'login' in its name and the current user's name
# [START hypercomputer_gpu_train_qwen2_slurm_download_login_node]
LOGIN_NODE=$(gcloud compute instances list \
  --project="${PROJECT_ID}" \
  --filter="name ~ .*login.* AND name ~ .*${CURRENT_USER}.*" \
  --format="value(name)" | head -n 1)
# [END hypercomputer_gpu_train_qwen2_slurm_download_login_node]

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

# Checking if the rule for IAP already exists to avoid creating a duplicate
FIREWALL_EXISTS=$(gcloud compute firewall-rules list \
  --project="${PROJECT_ID:-}" \
  --filter="name=allow-ssh-ingress-from-iap AND network=${CLUSTER_NETWORK}" \
  --format="value(name)" 2>/dev/null || echo "")

if [ -z "${FIREWALL_EXISTS}" ]; then
  echo "Creating missing firewall rule 'allow-ssh-ingress-from-iap' for network ${CLUSTER_NETWORK}..."
# [START hypercomputer_gpu_train_qwen2_slurm_firewall_rule]
  gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
    --project="${PROJECT_ID:-}" \
    --network="${CLUSTER_NETWORK}" \
    --direction=INGRESS \
    --action=allow \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP)"
# [END hypercomputer_gpu_train_qwen2_slurm_firewall_rule]
  echo "Firewall rule created successfully."
else
  echo "Firewall rule 'allow-ssh-ingress-from-iap' already exists for this network. Skipping creation."
fi

# 2. SCP scripts to login node
echo "[$(date)] Uploading workload scripts to login node..."
gcloud compute scp \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  ./install_environment.sh \
  ./requirements.txt \
  ./submit.slurm \
  ./accelerate_config.yaml \
  ./train.py \
  ./preprocess_data.py \
  "${LOGIN_NODE}":~/

# 3. Connect and run environment setup & submit job
echo "[$(date)] Running environment setup and submitting Slurm job on login node..."

# Run ssh and capture stdout to get the Job ID.
# Since we need to run multiple commands, we chain them.
SSH_CMD="export HF_TOKEN='${HF_TOKEN}' && export HUGGING_FACE_TOKEN='${HF_TOKEN}' && chmod +x install_environment.sh && ./install_environment.sh && sbatch submit.slurm"

SSH_OUTPUT=$(gcloud compute ssh "${LOGIN_NODE}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --command="${SSH_CMD}")

echo "${SSH_OUTPUT}"

# Parse job ID
JOB_ID=$(echo "${SSH_OUTPUT}" | grep -oP 'Submitted batch job \K\d+')

if [ -z "${JOB_ID}" ]; then
  echo "Error: Failed to submit Slurm job or parse Job ID." >&2
  exit 1
fi
echo "Successfully submitted Slurm job ID: ${JOB_ID}"

# 4. Poll job status until it finishes
echo "[$(date)] Monitoring Slurm job ${JOB_ID}..."
LIMIT=240 # 2 hours maximum polling (30s * 240)
count=0

while gcloud compute ssh "${LOGIN_NODE}" --project="${PROJECT_ID}" --zone="${ZONE}" --tunnel-through-iap --command="squeue -j ${JOB_ID}" 2>/dev/null | grep -q "${JOB_ID}"; do
  if [ ${count} -ge ${LIMIT} ]; then
    echo "Timeout waiting for Slurm job ${JOB_ID} to complete." >&2
    exit 1
  fi
  echo "Job ${JOB_ID} is still running. Waiting 30 seconds... (${count}/${LIMIT})"
  sleep 30
  count=$((count+1))
done

echo "[$(date)] Slurm job ${JOB_ID} has finished execution."
echo "[$(date)] ==================== Workload Execution Complete ===================="
