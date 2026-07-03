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

echo "[$(date)] ==================== Starting Validation... ===================="

# 1. Identify login node
echo "[$(date)] Finding login node for cluster ${CLUSTER_NAME}..."
declare -r LOGIN_NODE="$(gcloud compute instances list \
                          --project="${PROJECT_ID}" \
                          --filter="labels.ghpc_deployment='${CLUSTER_NAME}' AND labels.slurm_instance_role='login'" \
                          --format="value(name)" | head -n 1)"

if [ -z "${LOGIN_NODE}" ]; then
  echo "Error: Could not find login node for cluster ${CLUSTER_NAME}." >&2
  exit 1
fi
echo "Found login node: ${LOGIN_NODE}"

# 2. Fetch all slurm logs from login node
echo "[$(date)] Fetching Slurm output and error logs from login node..."
gcloud compute ssh "${LOGIN_NODE}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --command="cat ~/slurm-*.out ~/slurm-*.err" > slurm_job_logs.txt || true

echo "--------------------------------------------------------------------------------"
echo "Captured Slurm Logs:"
echo "--------------------------------------------------------------------------------"
cat slurm_job_logs.txt
echo "--------------------------------------------------------------------------------"

# 3. Assert successful training
echo "Checking for successful training indicator ('Training finished.')..."
if grep -q "Training finished." slurm_job_logs.txt; then
  echo "[$(date)] Validation passed: 'Training finished.' found in logs."
else
  echo "[$(date)] Validation failed: 'Training finished.' NOT found in logs." >&2
  exit 1
fi

echo "[$(date)] ==================== Validation Complete. ===================="
