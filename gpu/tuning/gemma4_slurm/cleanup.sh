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

echo "[$(date)] ==================== Starting Cleanup... ===================="

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"

export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 1. Delete Slurm cluster
echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
gcluster destroy "${BASEDIR}/${CLUSTER_NAME}" --auto-approve --robust || true

# 2. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${BUCKET_NAME}..."
gcloud storage rm --recursive "gs://${BUCKET_NAME}" --quiet || true

# 3. Clean up temporary directory
echo "[$(date)] Cleaning up temporary directory ${BASEDIR}..."
rm -rf "${BASEDIR}/${CLUSTER_NAME}"
rm -rf "${CLUSTER_TOOLKIT_PATH}"
rm -rf "${BASEDIR}/.ghpc"

echo "[$(date)] ==================== Cleanup Complete. ===================="
