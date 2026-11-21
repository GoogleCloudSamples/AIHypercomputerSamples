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

RAY_CLUSTER_NAME="gemma4-tuning"
CLUSTER_DISKS=""

RUNNING_OPERATIONS="$(gcloud container operations list \
    --project="${PROJECT_ID}" --location="${REGION}" \
    --filter="status=RUNNING AND targetLink~/clusters/${CLUSTER_NAME}" \
    --format="value(name)" 2> /dev/null || true)"
# Poll instead of using `gcloud container operations wait`, which gives up after 20 minutes.
OPERATIONS_DEADLINE=$((SECONDS + 3600))
for OPERATION in ${RUNNING_OPERATIONS}; do
    echo "Waiting for running cluster operation ${OPERATION} to finish..."
    while true; do
        OPERATION_STATUS="$(gcloud container operations describe "${OPERATION}" \
            --project="${PROJECT_ID}" --location="${REGION}" \
            --format="value(status)" 2> /dev/null || true)"
        if [[ ! "${OPERATION_STATUS}" =~ ^(PENDING|RUNNING|ABORTING)$ ]]; then
            break
        fi
        if [[ ${SECONDS} -ge ${OPERATIONS_DEADLINE} ]]; then
            echo "Warning: operation ${OPERATION} is still ${OPERATION_STATUS}; continuing with the cleanup." >&2
            break
        fi
        sleep 30
    done
done

if gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" --location="${REGION}"; then
    CLUSTER_DISKS="$(kubectl get pv \
        -o jsonpath='{range .items[*]}{.spec.csi.volumeHandle}{"\n"}{end}' || true)"
    set +e
# [START hypercomputer_gpu_tune_gemma4_ray_delete_ray_resources]
kubectl delete rayjob gemma4-tuning-job --ignore-not-found=true --timeout=300s
echo "[$(date)] ==================== Ray job deleted. ===================="

kubectl delete configmap gemma4-tuning-code --ignore-not-found=true
echo "[$(date)] ==================== ConfigMap deleted. ===================="

kubectl delete raycluster gemma4-tuning --ignore-not-found=true --timeout=600s
echo "[$(date)] ==================== Ray cluster deleted. ===================="
# [END hypercomputer_gpu_tune_gemma4_ray_delete_ray_resources]
    kubectl wait --for=delete pod -l "ray.io/cluster=${RAY_CLUSTER_NAME}" --timeout=600s
    kubectl wait --for=delete pv --all --timeout=600s
    set -e
else
    echo "Warning: couldn't get credentials for ${CLUSTER_NAME}; skipping the Kubernetes resources." >&2
fi

# [START hypercomputer_gpu_tune_gemma4_ray_cleanup]
gcloud container clusters delete "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --quiet || true
echo "[$(date)] ==================== GKE cluster deleted. ===================="

if gcloud storage buckets describe "gs://${GCS_BUCKET}" \
    --project="${PROJECT_ID}" > /dev/null 2>&1; then
    gcloud storage rm -r "gs://${GCS_BUCKET}" --project="${PROJECT_ID}" || true
    echo "[$(date)] ==================== GCS bucket deleted. ===================="
else
    echo "[$(date)] ==================== GCS bucket did not exist (Skipping). ===================="
fi

gcloud iam service-accounts delete "${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --quiet || true
echo "[$(date)] ==================== Google Service Account deleted. ===================="
# [END hypercomputer_gpu_tune_gemma4_ray_cleanup]

LEFTOVERS=0
if gcloud container clusters describe "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" --location="${REGION}" > /dev/null 2>&1; then
    echo "Error: GKE cluster '${CLUSTER_NAME}' still exists."
    LEFTOVERS=1
fi
if gcloud storage buckets describe "gs://${GCS_BUCKET}" \
    --project="${PROJECT_ID}" > /dev/null 2>&1; then
    echo "Error: Bucket 'gs://${GCS_BUCKET}' still exists."
    LEFTOVERS=1
fi
for DISK in ${CLUSTER_DISKS}; do
    DISK_NAME="${DISK##*/}"
    DISK_ZONE="$(cut -d/ -f4 <<< "${DISK}")"
    if gcloud compute disks describe "${DISK_NAME}" \
        --project="${PROJECT_ID}" --zone="${DISK_ZONE}" > /dev/null 2>&1; then
        echo "Deleting leftover disk '${DISK}'..."
        if ! gcloud compute disks delete "${DISK_NAME}" \
            --project="${PROJECT_ID}" --zone="${DISK_ZONE}" --quiet; then
            echo "Error: Disk '${DISK}' still exists."
            LEFTOVERS=1
        fi
    fi
done
exit "${LEFTOVERS}"
