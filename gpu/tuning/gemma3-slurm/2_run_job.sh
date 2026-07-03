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

while true; do
  SSH_CMD="squeue -h -j '${JOB_ID}' 2>/dev/null"
  STATUS="$(gcloud compute ssh "${LOGIN_NODE}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --command="${SSH_CMD}")"

  if [ -z "${STATUS}" ]; then
    echo "[$(date)] Job ${JOB_ID} is no longer in squeue."
    break
  fi
  echo "[$(date)] Job ${JOB_ID} is active in squeue. Waiting 60 seconds..."
  sleep 60
done

echo "[$(date)] Slurm job ${JOB_ID} has finished execution."
echo "[$(date)] ==================== Workload Execution Complete ===================="
