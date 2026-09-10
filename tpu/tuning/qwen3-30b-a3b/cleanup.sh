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

# Extract the unique benchmark run prefix (e.g., pkb-ecc4ef8c-0)
RUN_PREFIX=$(echo "${CLUSTER_NAME:-pkb-}" | grep -oE '^pkb-[a-f0-9]+-[0-9]+' || echo "${CLUSTER_NAME:-pkb-}")

echo "1. Fast-path: Triggering immediate deletion for all matching GKE clusters..."
# Retrieve names and locations of all clusters matching the prefix (both regional and zonal)
while read -r c_name c_loc; do
  if [ -n "$c_name" ] && [ -n "$c_loc" ]; then
    echo " -> Triggering async deletion of cluster: ${c_name} in ${c_loc}..."
    # Delete workloads if K8s API is still responsive
    xpk workload delete --workload "qwen-hf-to-mt" --cluster "${c_name}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
    xpk workload delete --workload "qwen-training" --cluster "${c_name}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true
    xpk workload delete --workload "qwen-mt-to-hf" --cluster "${c_name}" --project="${PROJECT}" --zone="${ZONE}" 2>/dev/null || true

    # Request cluster deletion in GCP - cascades to remove all node pools and TPU nodes
    gcloud container clusters delete "${c_name}" --location="${c_loc}" --project="${PROJECT}" --quiet --async 2>/dev/null || true
  fi
done < <(gcloud container clusters list --project="${PROJECT}" --filter="name~'^${RUN_PREFIX}'" --format="value(name,location)" 2>/dev/null || true)

# 2. Cleanup Managed Instance Groups (IGMs) across the target zone
echo "2. Cleaning up residual managed instance groups (IGMs)..."
gcloud compute instance-groups managed list \
  --project="${PROJECT}" \
  --filter="zone:'${ZONE}' AND (name~'${RUN_PREFIX}' OR name~'gke' OR name~'tpu' OR name~'pkb')" \
  --format="value(name,zone.basename())" 2>/dev/null | while read -r igm_name igm_zone; do
    if [ -n "$igm_name" ] && [ -n "$igm_zone" ]; then
      echo " -> Deleting residual IGM: $igm_name in $igm_zone"
      gcloud compute instance-groups managed delete "$igm_name" --zone="$igm_zone" --project="${PROJECT}" --quiet 2>/dev/null || true
    fi
done

# 3. Terminate all residual VM instances (TPU + CPU nodes)
echo "3. Terminating residual VM instances..."
gcloud compute instances list \
  --project="${PROJECT}" \
  --zones="${ZONE}" \
  --filter="(labels.goog-k8s-cluster-name~'^${RUN_PREFIX}' OR name~'^gke-${RUN_PREFIX}' OR name~'^gke-tpu' OR machineType:ct6e-standard-4t)" \
  --format="value(name,zone.basename())" 2>/dev/null | while read -r name zone; do
    if [ -n "$name" ] && [ -n "$zone" ]; then
      echo " -> Deleting instance: $name ($zone)"
      gcloud compute instances delete "$name" --zone="$zone" --project="${PROJECT}" --quiet 2>/dev/null || true
    fi
done

# 3b. Force cleanup of any lingering TPU VMs bound to the specific reservation
if [ -n "${RESERVATION:-}" ]; then
  echo "Checking for lingering TPU instances specifically bound to reservation ${RESERVATION}..."
  gcloud compute instances list \
    --project="${PROJECT}" \
    --zones="${ZONE}" \
    --filter="machineType:ct6e-standard-4t" \
    --format="value(name,zone.basename())" 2>/dev/null | while read -r tpu_vm tpu_zone; do
      if [ -n "$tpu_vm" ]; then
        echo " -> Force deleting lingering TPU VM: $tpu_vm ($tpu_zone)"
        gcloud compute instances delete "$tpu_vm" --zone="$tpu_zone" --project="${PROJECT}" --quiet 2>/dev/null || true
      fi
  done
fi

# 4. Clean up Pathways ANP networking stack (Firewalls -> Subnets -> VPCs)
RUN_HASH=$(echo "${RUN_PREFIX}" | sed -E 's/pkb-//; s/-cluster//')

if [ -n "$RUN_HASH" ]; then
  echo "4. Cleaning up ANP networking stack for run hash: ${RUN_HASH}..."

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

# 5. Verify TPU reservation release with active sweep
if [ -n "${RESERVATION:-}" ]; then
  echo "5. Verifying TPU reservation ${RESERVATION} release..."
  for i in {1..10}; do
    IN_USE=$(gcloud compute reservations describe "${RESERVATION}" \
      --project="${PROJECT}" \
      --zone="${ZONE}" \
      --format="value(specificReservation.inUseCount)" 2>/dev/null || echo "0")

    if [ -z "$IN_USE" ] || [ "$IN_USE" -eq 0 ]; then
      echo "TPU reservation ${RESERVATION} is completely free (0 chips in use)."
      break
    fi

    echo "TPU chips still in use: ${IN_USE}. Actively terminating residual nodes... ($i/10)"
    gcloud compute instances list \
      --project="${PROJECT}" \
      --zones="${ZONE}" \
      --filter="machineType:ct6e-standard-4t" \
      --format="value(name)" 2>/dev/null | xargs -r gcloud compute instances delete --zone="${ZONE}" --project="${PROJECT}" --quiet 2>/dev/null || true
    sleep 5
  done
fi

# 6. Clean up run artifacts from Cloud Storage
echo "6. Cleaning up run artifacts from Cloud Storage..."
if [ -n "${GCS_BUCKET:-}" ] && [ -n "${MODEL_NAME:-}" ]; then
  gcloud storage rm --recursive "gs://${GCS_BUCKET}/${MODEL_NAME}/" 2>/dev/null || echo "Info: No artifacts found under gs://${GCS_BUCKET}/${MODEL_NAME}/"
fi

# [END hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]
echo "[$(date)] ==================== Resources cleaned up. ===================="
