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

declare -r JOB_NAME="finetune-job"
declare -r LOG_FILE="$(mktemp)"

echo "[$(date)] ==================== Starting Validation... ===================="

echo "Fetching full logs for verification..."
kubectl logs "jobs/${JOB_NAME}" > "${LOG_FILE}"

# Count how many times "Training finished." appears
declare -r TRAINING_COUNT="$(grep -o "Training finished." "${LOG_FILE}" | wc -l)"
if [[ "${TRAINING_COUNT}" -ne 8 ]]; then
    echo "Validation Failed! Count = ${TRAINING_COUNT}"
    exit 1
fi

echo "Validation Succeeded!"
