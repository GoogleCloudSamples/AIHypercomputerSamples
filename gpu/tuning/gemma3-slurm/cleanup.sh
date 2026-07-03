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

# gpu/tuning/gemma3-slurm/miani-cluster/.ghpc/artifacts/cluster-env_outputs.tfvars

declare -r SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
declare -r BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"

export PATH="${CLUSTER_TOOLKIT_PATH}:$PATH"
gcluster --version

# 1. Delete Slurm cluster
echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
gcluster destroy "${CLUSTER_NAME}" --auto-approve || true

# 2. Delete GCS bucket
echo "[$(date)] Deleting GCS bucket gs://${BUCKET_NAME}..."
gcloud storage buckets delete "gs://${BUCKET_NAME}" --quiet || true

echo "[$(date)] ==================== Cleanup Complete. ===================="
