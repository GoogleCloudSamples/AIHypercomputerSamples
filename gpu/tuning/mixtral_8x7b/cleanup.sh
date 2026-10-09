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

if [ -z "${DEPLOYMENT_NAME:-}" ] || [ -z "${PROJECT_ID:-}" ] || [ -z "${REGION:-}" ] || [ -z "${BUCKET_NAME:-}" ]; then
    echo "Error: DEPLOYMENT_NAME, PROJECT_ID, REGION, and BUCKET_NAME environment variables must be set." >&2
    exit 1
fi

echo "[$(date)] ==================== Starting Cleanup... ===================="

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"

export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 1. Delete Slurm cluster
echo "[$(date)] Destroying Slurm cluster ${DEPLOYMENT_NAME}..."
gcluster destroy "${BASEDIR}/${DEPLOYMENT_NAME}" --auto-approve --robust || true

# Cleanup for a workaround with "default-nemo-rl" VPC network (lines 38-47)
echo "[$(date)] Ensuring default-nemo-rl network and any remaining firewall rules are removed..."
FW_RULES=$(gcloud compute firewall-rules list \
  --project="${PROJECT_ID}" \
  --filter="network~default-nemo-rl" \
  --format="value(name)" \
  --quiet 2>/dev/null || true)
if [ -n "${FW_RULES}" ]; then
  gcloud compute firewall-rules delete ${FW_RULES} --project="${PROJECT_ID}" --quiet || true
fi
gcloud compute networks delete default-nemo-rl --project="${PROJECT_ID}" --quiet 2>/dev/null || true

# Delete Packer-built custom compute image (not removed by gcluster destroy)
echo "[$(date)] Deleting custom compute images for ${DEPLOYMENT_NAME} if present..."
IMAGES=$(gcloud compute images list \
  --project="${PROJECT_ID}" \
  --filter="family=${DEPLOYMENT_NAME}-u24" \
  --format="value(name)" \
  --quiet 2>/dev/null || true)
if [ -n "${IMAGES}" ]; then
  gcloud compute images delete ${IMAGES} --project="${PROJECT_ID}" --quiet || true
fi

# 2. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${BUCKET_NAME}..."
# [START hypercomputer_gpu_tune_mixtral_slurm_destroy_gcs]
gcloud storage rm --recursive "gs://${BUCKET_NAME}" --quiet || true
# [END hypercomputer_gpu_tune_mixtral_slurm_destroy_gcs]

# 3. Clean up temporary directories and toolkit files
echo "[$(date)] Cleaning up temporary directories and toolkit files..."
rm -rf "${BASEDIR}/.ghpc"
rm -rf "${BASEDIR}/${DEPLOYMENT_NAME}"
rm -rf "${CLUSTER_TOOLKIT_PATH}"
rm -f "${BASEDIR}/gcluster"

echo "[$(date)] ==================== Cleanup Complete. ===================="
