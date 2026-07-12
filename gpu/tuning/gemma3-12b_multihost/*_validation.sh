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

declare -r JOB_NAME="finetune-jobset-workers-0"

echo "Waiting for JobSet to create Job ${JOB_NAME}..."
until kubectl get job "${JOB_NAME}" &>/dev/null; do
    echo "Job not found yet, retrying in 5 seconds..."
    sleep 5
done

echo "Waiting for Job ${JOB_NAME} to complete..."
kubectl wait --for=condition=complete "job/${JOB_NAME}" --timeout=14400s || {
    echo "Job failed or timed out. Fetching status and logs..."
    kubectl describe job "${JOB_NAME}"
    kubectl logs "jobs/${JOB_NAME}" || true
    exit 1
}

echo "Job completed. Fetching full logs for verification..."
declare -r LOG_FILE="$(mktemp)"
kubectl logs -l "job-name=${JOB_NAME}" > "${LOG_FILE}"
trap 'rm -f "${LOG_FILE}"' EXIT

if ! grep -q "Training finished." "${LOG_FILE}"; then
    echo "Validation Failed! Could not find 'Training finished.' in logs."
    exit 1
fi

if ! grep -q "Saving final model to" "${LOG_FILE}"; then
    echo "Validation Failed! Could not find 'Saving final model to' in logs."
    exit 1
fi

echo "Validation Succeeded!"
