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

if [ -d "venvp3" ]; then
  source venvp3/bin/activate
fi

echo "[$(date)] ==================== Cleaning up resources... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]

# 1. Resolve full cluster target (handles the 4-char random hex suffix from setup_cluster.sh)
TARGET_CLUSTER="${CLUSTER_NAME}"
REAL_CLUSTER=$(gcloud container clusters list \
  --project="${PROJECT}" \
  --location="${REGION}" \
  --filter="name~'^${CLUSTER_NAME}'" \
  --format="value(name)" 2>/dev/null | head -n 1 || true)

if [ -n "$REAL_CLUSTER" ]; then
  TARGET_CLUSTER="$REAL_CLUSTER"
  echo "Target active cluster identified: ${TARGET_CLUSTER}"
fi

# 2. Delete active workloads and JobSets created during conversion/training
echo "Deleting active XPK workloads..."
xpk workload delete --workload "qwen-hf-to-mt" --cluster "${TARGET_CLUSTER}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
xpk workload delete --workload "qwen-training" --cluster "${TARGET_CLUSTER}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
xpk workload delete --workload "qwen-mt-to-hf" --cluster "${TARGET_CLUSTER}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true

# 3. Wait for any in-flight cluster operations to finish
echo "Waiting for background cluster operations to complete..."
while gcloud container operations list \
  --project="${PROJECT}" \
  --location="${REGION}" \
  --filter="status=RUNNING AND targetLink:${TARGET_CLUSTER}" \
  --format="value(name)" 2>/dev/null | grep -q .; do
  sleep 15
done

# 4. Terminate TPU VM instances attached to the cluster (releases subnet interfaces)
echo "Terminating TPU VM instances attached to ${TARGET_CLUSTER}..."
gcloud compute instances list \
  --project="${PROJECT}" \
  --filter="labels.goog-k8s-cluster-name:${TARGET_CLUSTER}" \
  --format="value(name,zone)" 2>/dev/null | while read -r name zone; do
    if [ -n "$name" ]; then
      echo " -> Deleting instance: $name ($zone)"
      gcloud compute instances delete "$name" --zone="$zone" --project="${PROJECT}" --quiet || true
    fi
done

# 5. Delete GKE cluster
echo "Deleting GKE cluster ${TARGET_CLUSTER}..."
xpk cluster delete --cluster "${TARGET_CLUSTER}" --project "${PROJECT}" --zone "${ZONE}" --force 2>/dev/null || \
  gcloud container clusters delete "${TARGET_CLUSTER}" --location="${REGION}" --project="${PROJECT}" --quiet --async 2>/dev/null || \
  echo "Warning: Failed to delete cluster ${TARGET_CLUSTER}"

# 6. Clean up Pathways ANP networking stack (Firewall Rules -> Subnets -> VPC Networks)
CLUSTER_ID_HASH=$(echo "${TARGET_CLUSTER}" | sed -E 's/pkb-//; s/-cluster//; s/-[a-f0-9]{4}$//')

if [ -n "$CLUSTER_ID_HASH" ]; then
  echo "Cleaning up ANP networking stack for identifier: ${CLUSTER_ID_HASH}..."

  # 6a. Delete firewall rules
  gcloud compute firewall-rules list \
    --project="${PROJECT}" \
    --filter="network~'gke-anp.*${CLUSTER_ID_HASH}'" \
    --format="value(name)" 2>/dev/null | while read -r fw; do
      [ -n "$fw" ] && gcloud compute firewall-rules delete "$fw" --project="${PROJECT}" --quiet || true
  done

  # Wait briefly for firewall deletion propagation
  sleep 5

  # 6b. Delete subnetworks
  gcloud compute networks subnets list \
    --project="${PROJECT}" \
    --regions="${REGION}" \
    --filter="name~'gke-anp.*${CLUSTER_ID_HASH}'" \
    --format="value(name)" 2>/dev/null | while read -r subnet; do
      [ -n "$subnet" ] && gcloud compute networks subnets delete "$subnet" --region="${REGION}" --project="${PROJECT}" --quiet || true
  done

  # 6c. Delete VPC networks
  gcloud compute networks list \
    --project="${PROJECT}" \
    --filter="name~'gke-anp.*${CLUSTER_ID_HASH}'" \
    --format="value(name)" 2>/dev/null | while read -r net; do
      [ -n "$net" ] && gcloud compute networks delete "$net" --project="${PROJECT}" --quiet || true
  done
fi

# 7. Delete Cloud Storage bucket and Artifact Registry repository
echo "Cleaning up Cloud Storage bucket and Artifact Registry repository..."
gcloud storage rm --recursive "gs://${GCS_BUCKET}" 2>/dev/null || echo "Warning: Failed to delete bucket gs://${GCS_BUCKET}"
gcloud artifacts repositories delete maxtext-images --location="${REGION}" --project="${PROJECT}" --quiet 2>/dev/null || echo "Warning: Failed to delete repository maxtext-images"

# [END hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]
echo "[$(date)] ==================== Resources cleaned up. ===================="
