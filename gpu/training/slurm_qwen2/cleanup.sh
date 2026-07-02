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

echo "[$(date)] ==================== Starting Cleanup... ===================="

# 1. Destroy Slurm cluster via cluster-toolkit
if [ -d "cluster-toolkit" ]; then
  echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
  cd cluster-toolkit/examples/machine-learning/a4-highgpu-8g
  ../../../gcluster destroy "${CLUSTER_NAME}" --auto-approve || true
  cd ../../../..

  echo "[$(date)] Removing cluster-toolkit directory..."
  rm -rf cluster-toolkit
else
  echo "cluster-toolkit directory not found, skipping cluster destruction."
fi

# 2. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${GCS_BUCKET}..."
gcloud storage rm -r "gs://${GCS_BUCKET}" --quiet || true

echo "[$(date)] ==================== Cleanup Complete. ===================="
