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

set -e

CLEANUP_RC=0

kubectl delete jobset finetune-jobset --ignore-not-found=true || true
echo "[$(date)] ==================== JobSet deleted. ===================="

# GKE Autopilot may run background operations (e.g. RESIZE_CLUSTER) that cause
# "Cluster is running incompatible operation" (HTTP 400) if delete runs immediately.
wait_for_gke_operations() {
    echo "Waiting for in-progress GKE operations on ${CLUSTER_NAME} to finish..."
    for attempt in $(seq 1 80); do
        if ! ACTIVE_OPS=$(gcloud container operations list \
            --project="${PROJECT_ID}" \
            --location="${CLUSTER_REGION}" \
            --filter="status!=DONE AND targetLink~/clusters/${CLUSTER_NAME}(/|$)" \
            --format="value(name)" 2>/dev/null); then
            echo "  Warning: failed to list GKE operations (attempt ${attempt}/80), retrying in 15s..."
            sleep 15
            continue
        fi
        if [[ -z "${ACTIVE_OPS}" ]]; then
            echo "No active GKE operations on ${CLUSTER_NAME}."
            return 0
        fi
        echo "  Active operation(s): ${ACTIVE_OPS//$'\n'/, } (attempt ${attempt}/80), waiting 15s..."
        sleep 15
    done
    echo "  Warning: timed out waiting for GKE operations on ${CLUSTER_NAME} to finish." >&2
    return 1
}

CLUSTER_DELETED=false
for delete_attempt in $(seq 1 5); do
    wait_for_gke_operations || true
    DELETE_OUTPUT=""
    if DELETE_OUTPUT=$(gcloud container clusters delete "${CLUSTER_NAME}" \
        --project="${PROJECT_ID}" \
        --location="${CLUSTER_REGION}" \
        --quiet 2>&1); then
        [[ -n "${DELETE_OUTPUT}" ]] && echo "${DELETE_OUTPUT}"
        CLUSTER_DELETED=true
        break
    fi
    echo "${DELETE_OUTPUT}" >&2
    if [[ "${DELETE_OUTPUT}" == *"NOT_FOUND"* ]] || [[ "${DELETE_OUTPUT}" == *"Not found"* ]]; then
        echo "Cluster ${CLUSTER_NAME} already deleted or not found."
        CLUSTER_DELETED=true
        break
    fi
    echo "  Failed to delete cluster ${CLUSTER_NAME} (attempt ${delete_attempt}/5), retrying in 30s..." >&2
    sleep 30
done

if [[ "${CLUSTER_DELETED}" == "true" ]]; then
    echo "[$(date)] ==================== Cluster deleted. ===================="
else
    echo "ERROR: failed to delete cluster ${CLUSTER_NAME} after 5 attempts." >&2
    CLEANUP_RC=1
fi

gcloud artifacts repositories delete gemma \
    --location="${ARTIFACT_REPO_LOCATION}" \
    --quiet || true
echo "[$(date)] ==================== Artifact Registry deleted. ===================="

HF_USERNAME="$(curl -sSf -H "Authorization: Bearer ${HF_TOKEN}" \
    https://huggingface.co/api/whoami-v2 \
    | python3 -c "import json, sys; print(json.load(sys.stdin)['name'])" \
    2>/dev/null)" || true
if [[ -n "${HF_USERNAME:-}" ]] && curl -sSf -o /dev/null -X DELETE "https://huggingface.co/api/models/${HF_USERNAME}/gemma-31b-text-to-sql" -H "Authorization: Bearer ${HF_TOKEN}"; then
    echo "[$(date)] ==================== Hugging Face model repo deleted. ===================="
else
    echo "[$(date)] WARNING: could not delete Hugging Face model repo" \
        "gemma-31b-text-to-sql (already deleted or invalid HF_TOKEN)."
fi

exit "${CLEANUP_RC}"
