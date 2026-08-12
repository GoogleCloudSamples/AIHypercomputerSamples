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
