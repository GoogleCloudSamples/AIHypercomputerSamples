#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -uo pipefail

if [ -d "venvp3" ]; then
  source venvp3/bin/activate
fi

echo "[$(date)] ==================== Cleaning up resources... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]

# Extract the unique benchmark run prefix (e.g., pkb-303e58c9-0 -> pkb-303e58c9)
RUN_PREFIX=$(echo "${CLUSTER_NAME:-pkb-}" | grep -oE '^pkb-[a-f0-9]+' || echo "${CLUSTER_NAME:-pkb-}")
CURRENT_HOST=$(hostname 2>/dev/null || echo "")

echo "Runner host detected as: '${CURRENT_HOST}' (Protected from self-deletion)"
echo "Target cleanup prefix: '${RUN_PREFIX}'"

echo "1. Freeing TPU reservation immediately by scaling TPU instance groups to 0..."
# Resizing prevents IGM from ever spawning new VM instances back into STAGING/RUNNING
gcloud compute instance-groups managed list \
  --project="${PROJECT}" \
  --filter="zone:'${ZONE}' AND (name~'${RUN_PREFIX}' OR name~'tpu')" \
  --format="value(name,zone.basename())" 2>/dev/null | while read -r igm_name igm_zone; do
    if [ -n "$igm_name" ] && [ -n "$igm_zone" ]; then
      echo " -> Resizing IGM to 0: $igm_name in $igm_zone"
      gcloud compute instance-groups managed resize "$igm_name" --size=0 --zone="$igm_zone" --project="${PROJECT}" --quiet 2>/dev/null || true
    fi
done

echo "2. Triggering deletion for all matching GKE clusters..."
while read -r c_name c_loc; do
  if [ -n "$c_name" ] && [ -n "$c_loc" ]; then
    echo " -> Requesting deletion of cluster: ${c_name} in ${c_loc}..."
    xpk workload delete --workload "qwen-hf-to-mt" --cluster "${c_name}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
    xpk workload delete --workload "qwen-training" --cluster "${c_name}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
    xpk workload delete --workload "qwen-mt-to-hf" --cluster "${c_name}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true

    # Retry cluster deletion in case it is temporarily reconciling
    for attempt in $(seq 1 30); do
      if gcloud container clusters delete "${c_name}" --location="${c_loc}" --project="${PROJECT}" --quiet --async 2>/dev/null; then
        echo "Successfully requested deletion of ${c_name}."
        break
      fi
      echo "Cluster ${c_name} busy. Retrying in 10s ($attempt/30)..."
      sleep 10
    done
  fi
done < <(gcloud container clusters list --project="${PROJECT}" --filter="name~'^${RUN_PREFIX}'" --format="value(name,location)" 2>/dev/null || true)

echo "3. Waiting for GKE clusters to completely vanish from GCP..."
for i in $(seq 1 30); do
  ACTIVE_CLUSTERS=$(gcloud container clusters list --project="${PROJECT}" --filter="name~'^${RUN_PREFIX}'" --format="value(name)" 2>/dev/null || true)
  if [ -z "$ACTIVE_CLUSTERS" ]; then
    echo "All GKE clusters matching ${RUN_PREFIX} have been completely removed."
    break
  fi
  echo "Clusters still terminating (${ACTIVE_CLUSTERS}). Waiting 15s ($i/30)..."
  sleep 15
done

echo "4. Hard-deleting any residual Managed Instance Groups (IGMs)..."
# Targeted strictly at GKE node pool groups to prevent hitting any standalone benchmark groups
gcloud compute instance-groups managed list \
  --project="${PROJECT}" \
  --filter="zone:'${ZONE}' AND name~'gke-${RUN_PREFIX}'" \
  --format="value(name,zone.basename())" 2>/dev/null | while read -r igm_name igm_zone; do
    if [ -n "$igm_name" ] && [ -n "$igm_zone" ]; then
      echo " -> Force deleting residual IGM: $igm_name in $igm_zone"
      gcloud compute instance-groups managed delete "$igm_name" --zone="$igm_zone" --project="${PROJECT}" --quiet 2>/dev/null || true
    fi
done

echo "5. Terminating residual VM instances (TPU and GKE nodes, safely ignoring runner VM)..."
gcloud compute instances list \
  --project="${PROJECT}" \
  --zones="${ZONE}" \
  --filter="(labels.goog-k8s-cluster-name~'^${RUN_PREFIX}' OR name~'^gke-${RUN_PREFIX}' OR name~'^gke-tpu' OR machineType:ct6e-standard-4t)" \
  --format="value(name,zone.basename())" 2>/dev/null | while read -r name zone; do
    if [ -n "$name" ] && [ -n "$zone" ]; then
      # Absolute safety check: Never delete current host or external PKB driver VM
      if [[ "$name" == "$CURRENT_HOST" || ("$name" =~ -0$ && ! "$name" =~ ^gke-) ]]; then
        echo " -> Safely skipping active runner VM: $name"
        continue
      fi
      echo " -> Force deleting instance: $name ($zone)"
      gcloud compute instances delete "$name" --zone="$zone" --project="${PROJECT}" --quiet 2>/dev/null || true
    fi
done

echo "6. Cleaning up Pathways ANP networking stack (Firewalls -> Subnets -> Networks)..."
RUN_HASH=$(echo "${RUN_PREFIX}" | sed -E 's/pkb-//; s/-cluster//')
if [ -n "$RUN_HASH" ]; then
  gcloud compute firewall-rules list \
    --project="${PROJECT}" \
    --filter="network~'gke-anp.*${RUN_HASH}'" \
    --format="value(name)" 2>/dev/null | while read -r fw; do
      [ -n "$fw" ] && gcloud compute firewall-rules delete "$fw" --project="${PROJECT}" --quiet 2>/dev/null || true
    done

  gcloud compute networks subnets list \
    --project="${PROJECT}" \
    --filter="name~'gke-anp.*${RUN_HASH}'" \
    --format="value(name,region.basename())" 2>/dev/null | while read -r subnet sub_region; do
      if [ -n "$subnet" ]; then
        gcloud compute networks subnets delete "$subnet" --region="${sub_region:-$REGION}" --project="${PROJECT}" --quiet 2>/dev/null || true
      fi
  done

  gcloud compute networks list \
    --project="${PROJECT}" \
    --filter="name~'gke-anp.*${RUN_HASH}'" \
    --format="value(name)" 2>/dev/null | while read -r net; do
      [ -n "$net" ] && gcloud compute networks delete "$net" --project="${PROJECT}" --quiet 2>/dev/null || true
  done
fi

echo "7. Verifying TPU reservation release..."
if [ -n "${RESERVATION:-}" ]; then
  for i in $(seq 1 12); do
    IN_USE=$(gcloud compute reservations describe "${RESERVATION}" \
      --project="${PROJECT}" \
      --zone="${ZONE}" \
      --format="value(specificReservation.inUseCount)" 2>/dev/null || echo "0")

    if [ -z "$IN_USE" ] || [ "$IN_USE" -eq 0 ]; then
      echo "TPU reservation ${RESERVATION} is completely free (0 chips in use)."
      break
    fi

    echo "TPU chips still in use: ${IN_USE}. Waiting for GCP to finish release ($i/12)..."
    sleep 10
  done
fi

echo "8. Cleaning up run artifacts from Cloud Storage..."
if [ -n "${GCS_BUCKET:-}" ] && [ -n "${MODEL_NAME:-}" ]; then
  gcloud storage rm --recursive "gs://${GCS_BUCKET}/${MODEL_NAME}/" 2>/dev/null || echo "Info: No artifacts found under gs://${GCS_BUCKET}/${MODEL_NAME}/"
fi

# [END hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]
echo "[$(date)] ==================== Resources cleaned up. Everything is destroyed. ===================="
