#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

echo "[$(date)] ==================== Starting Validation ===================="

# Get recent logs from the Ray Head Pod for verification
echo "Fetching Ray head pod name..."
HEAD_POD=$(kubectl get pods -l ray.io/node-type=head -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -n "${HEAD_POD}" ]; then
  echo "--- Recent logs from Ray Head Pod (${HEAD_POD}) ---"
  kubectl logs "${HEAD_POD}" -c ray-head -n "${NAMESPACE}" --tail=50 || true
  echo "---------------------------------------------------"
else
  echo "Warning: Could not find active Ray head pod for log inspection."
fi

# Verify that Verl PPO training generated checkpoints in Cloud Storage
CHECKPOINT_DIR="gs://${GS_BUCKET}/verl/checkpoints/"
echo "Checking for created model checkpoints in ${CHECKPOINT_DIR}..."

CHECKPOINT_FOUND=false
for attempt in {1..6}; do
  if gcloud storage ls "${CHECKPOINT_DIR}" >/dev/null 2>&1; then
    CHECKPOINT_COUNT=$(gcloud storage ls "${CHECKPOINT_DIR}" 2>/dev/null | wc -l)
    if [[ "${CHECKPOINT_COUNT}" -gt 0 ]]; then
      echo "Found ${CHECKPOINT_COUNT} items in checkpoint directory."
      CHECKPOINT_FOUND=true
      break
    fi
  fi
  echo "Checkpoints not yet visible in GCS, waiting 5s (attempt ${attempt}/6)..."
  sleep 5
done

if [ "${CHECKPOINT_FOUND}" != "true" ]; then
    echo "Validation Failed: No checkpoints found in ${CHECKPOINT_DIR}."
    exit 1
fi

echo "[$(date)] Validation Succeeded! Verl RL training completed and checkpoints are available in GCS."
