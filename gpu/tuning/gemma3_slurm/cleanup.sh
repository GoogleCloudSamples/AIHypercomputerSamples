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

if [[ -z "${WORK_DIR:-}" ]]; then
  echo "Error: WORK_DIR is not set. Please source 0_env.sh" >&2
  exit 1
fi

echo "[$(date)] ==================== Starting Cleanup... ===================="

declare -r CLUSTER_TOOLKIT_PATH="${WORK_DIR}/cluster_toolkit"

export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 1. Delete Slurm cluster
echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
gcluster destroy "${WORK_DIR}/${CLUSTER_NAME}" --auto-approve || true

# 2. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${BUCKET_NAME}..."
gcloud storage buckets delete "gs://${BUCKET_NAME}" --quiet || true

# 3. Clean up temporary directory
echo "[$(date)] Cleaning up temporary directory ${WORK_DIR}..."
rm -rf "${WORK_DIR}"

echo "[$(date)] ==================== Cleanup Complete. ===================="
