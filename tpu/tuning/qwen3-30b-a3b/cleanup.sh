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

cleanup_anp_firewalls() {
  local hash="$1"
  local filter_expr=""
  if [ -n "$hash" ]; then
    filter_expr="(network ~ gke-anp-${hash} OR name ~ ${hash} OR name ~ ${CLUSTER_NAME})"
  else
    filter_expr="name ~ ${CLUSTER_NAME}"
  fi
  echo "Checking for ANP firewall rules matching: $filter_expr..."
  local fw_rules
  fw_rules=$(gcloud compute firewall-rules list --project="$PROJECT" --filter="$filter_expr" --format="value(name)" 2>/dev/null || true)
  if [ -n "$fw_rules" ]; then
    echo "Deleting ANP firewall rules: $fw_rules"
    echo "$fw_rules" | xargs -r -n 10 gcloud compute firewall-rules delete --project="$PROJECT" --quiet 2>/dev/null || true
  fi
}

echo "[$(date)] ==================== Cleaning up resources... ===================="
echo "Waiting for background cluster operations (like autoscaling) to finish..."
while gcloud container operations list --project=$PROJECT --location=$REGION --filter="status=RUNNING AND targetLink:$CLUSTER_NAME" --format="value(name)" | grep -q .; do
  sleep 30
done

if gcloud container clusters describe "$CLUSTER_NAME" --location="$REGION" --project="$PROJECT" &>/dev/null; then
  CLUSTER_ID=$(gcloud container clusters describe "$CLUSTER_NAME" --location="$REGION" --project="$PROJECT" --format="value(id)" 2>/dev/null || true)
  CLUSTER_HASH=""
  if [ -n "$CLUSTER_ID" ]; then
    CLUSTER_HASH="${CLUSTER_ID:0:8}"
    echo "Discovered cluster hash: $CLUSTER_HASH"
  fi

  echo "Attempting cluster deletion via xpk..."
  if ! xpk cluster delete --cluster "$CLUSTER_NAME" --project "$PROJECT" --zone "$ZONE" --force; then
    echo "Warning: xpk cluster delete failed. Purging ANP firewall rules and retrying via gcloud..."
    cleanup_anp_firewalls "$CLUSTER_HASH"
    gcloud container clusters delete "$CLUSTER_NAME" --location="$REGION" --project="$PROJECT" --quiet || echo "Warning: Direct cluster deletion failed"
  fi

  # Post-cluster deletion: remove any remaining ANP firewalls and networks
  if [ -n "$CLUSTER_HASH" ]; then
    cleanup_anp_firewalls "$CLUSTER_HASH"
    anp_networks=$(gcloud compute networks list --project="$PROJECT" --filter="name ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null || true)
    if [ -n "$anp_networks" ]; then
      echo "Cleaning up dangling ANP networks for cluster hash ${CLUSTER_HASH}..."
      echo "$anp_networks" | xargs -r -n 5 gcloud compute networks delete --project="$PROJECT" --quiet 2>/dev/null || true
    fi
  fi
fi

if gcloud storage buckets describe "gs://$GCS_BUCKET" --project="$PROJECT" &>/dev/null; then
  gcloud storage rm --recursive "gs://$GCS_BUCKET" || echo "Warning: Failed to delete bucket"
fi

if gcloud artifacts repositories describe maxtext-images --location=$REGION --project=$PROJECT &>/dev/null; then
  gcloud artifacts repositories delete maxtext-images --location=$REGION --project=$PROJECT --quiet || echo "Warning: Failed to delete repository"
fi
echo "[$(date)] ==================== Resources cleaned up. ===================="
