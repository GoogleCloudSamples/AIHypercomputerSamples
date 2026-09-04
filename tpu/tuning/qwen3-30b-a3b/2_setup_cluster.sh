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

echo "[$(date)] ==================== Creating Cluster... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
# Start with creating a new virtual environment to install XPK in.
VENV_DIR=venvp3
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install -q xpk==1.14.0

# Collision guard: append a random 4-character hex suffix if not present
if [[ ! "${CLUSTER_NAME}" =~ -[a-f0-9]{4}$ ]]; then
  RANDOM_SUFFIX=$(od -N 2 -t x1 /dev/urandom | head -1 | awk '{print $2$3}')
  export CLUSTER_NAME="${CLUSTER_NAME}-${RANDOM_SUFFIX}"
  echo "Using unique cluster name: ${CLUSTER_NAME}"
fi

# Retry loop to handle Kueue webhook installation race conditions
MAX_RETRIES=3
attempt=1

while [ $attempt -le $MAX_RETRIES ]; do
  echo "Attempting cluster creation (attempt $attempt/$MAX_RETRIES)..."

  if xpk cluster create-pathways \
    --num-slices="${CLUSTER_NODEPOOL_COUNT}" \
    --tpu-type="${TPU_TYPE}" \
    --pathways-gce-machine-type="${PW_CPU_MACHINE_TYPE}" \
    --project="${PROJECT}" \
    --zone="${ZONE}" \
    --cluster="${CLUSTER_NAME}" \
    --custom-cluster-arguments="--enable-ip-alias" \
    --custom-nodepool-arguments="--disk-size=500" \
    --reservation="${RESERVATION}" \
    --default-pool-cpu-machine-type=e2-standard-16; then
      echo "Cluster created successfully."
      break
  else
      echo "Warning: Attempt $attempt failed (likely due to a Kueue webhook timeout)."
      if [ $attempt -eq $MAX_RETRIES ]; then
        echo "ERROR: Maximum retry attempts reached. Exiting."
        exit 1
      fi

      echo "Cleaning up resources from the failed attempt..."
      xpk cluster delete --cluster "${CLUSTER_NAME}" --project "${PROJECT}" --zone "${ZONE}" --force 2>/dev/null || \
        gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" --quiet 2>/dev/null || true

      echo "Waiting 60 seconds for TPU reservation release..."
      sleep 60

      # Generate a new suffix for the next attempt to avoid API locks
      NEW_SUFFIX=$(od -N 2 -t x1 /dev/urandom | head -1 | awk '{print $2$3}')
      CLUSTER_NAME="${CLUSTER_NAME%-*}-${NEW_SUFFIX}"
      echo "New cluster name for next attempt: ${CLUSTER_NAME}"

      echo "Waiting 30 seconds before retrying..."
      sleep 30
      attempt=$((attempt + 1))
  fi
done

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --location="$REGION" \
  --project "$PROJECT"

# Error protection before "failed calling webhook mjobset.kb.io: No agent available"
echo "Waiting for JobSet controller and webhook service to become ready..."
kubectl wait --namespace jobset-system \
  --for=condition=ready pod \
  --selector=control-plane=jobset-controller-manager \
  --timeout=180s 2>/dev/null || true

sleep 20
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
echo "[$(date)] ==================== Cluster created. ===================="
