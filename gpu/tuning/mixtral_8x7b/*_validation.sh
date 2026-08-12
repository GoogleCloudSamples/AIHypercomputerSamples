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
echo "[$(date)] Finding login node for cluster ${DEPLOYMENT_NAME}..."
LOGIN_NODE="$(gcloud compute instances list \
  --project="${PROJECT_ID}" \
  --filter="labels.ghpc_deployment='${DEPLOYMENT_NAME}' AND labels.slurm_instance_role='login'" \
  --format="value(name)" | head -n 1)"

if [ -z "${LOGIN_NODE}" ]; then
  echo "Error: Could not find login node for cluster ${DEPLOYMENT_NAME}." >&2
  exit 1
fi
echo "Found login node: ${LOGIN_NODE}"

# 2. Ensure IAP firewall rule exists for network
echo "[$(date)] Identifying VPC Network and ensuring IAP firewall rule exists..."
VPC_NETWORK_URI=$(gcloud compute instances describe "${LOGIN_NODE}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --format="value(networkInterfaces[0].network)" 2>/dev/null || echo "")

CLUSTER_NETWORK=$(basename "${VPC_NETWORK_URI}")

if [ -n "${CLUSTER_NETWORK}" ]; then
  FIREWALL_RULE_NAME="allow-ssh-from-iap-${CLUSTER_NETWORK}"
  FIREWALL_EXISTS=$(gcloud compute firewall-rules list \
    --project="${PROJECT_ID}" \
    --filter="name=${FIREWALL_RULE_NAME} AND network=${CLUSTER_NETWORK}" \
    --format="value(name)" 2>/dev/null || echo "")

  if [ -z "${FIREWALL_EXISTS}" ]; then
    echo "Creating missing firewall rule '${FIREWALL_RULE_NAME}' for network ${CLUSTER_NETWORK}..."
    gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
      --project="${PROJECT_ID}" \
      --network="${CLUSTER_NETWORK}" \
      --direction=INGRESS \
      --action=allow \
      --rules=tcp:22 \
      --source-ranges=35.235.240.0/20 \
      --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP) for ${CLUSTER_NETWORK}" || true
  else
    echo "Firewall rule '${FIREWALL_RULE_NAME}' already exists."
  fi
fi

# 3. Check Slurm Job status using sacct
echo "[$(date)] Querying Slurm job history on login node..."
gcloud compute ssh "${LOGIN_NODE}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --command="sacct --format=JobID,JobName,State,ExitCode,Elapsed,Start,End" || true

# 4. Fetch Slurm output and error logs from login node
echo "[$(date)] Fetching Slurm output logs (mixtral-*.out) from login node..."
gcloud compute ssh "${LOGIN_NODE}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --command="cat ~/mixtral-*.out 2>/dev/null || cat ~/mixtral-*.err 2>/dev/null || echo 'No mixtral log files found yet.'" > slurm_job_logs.txt

echo "--------------------------------------------------------------------------------"
echo "Captured Slurm Logs Summary:"
echo "--------------------------------------------------------------------------------"
cat slurm_job_logs.txt | tail -n 40
echo "--------------------------------------------------------------------------------"

echo "[$(date)] ==================== Validation Complete ===================="
