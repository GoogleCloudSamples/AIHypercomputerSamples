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

# 1. Build and Submit
# [START hypercomputer_gpu_tune_gemma4_multihost_gke_build_submit]
gcloud builds submit . \
    --substitutions=_ARTIFACT_REPO_LOCATION="${ARTIFACT_REPO_LOCATION}"
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_build_submit]
echo "[$(date)] ==================== Build finished. ===================="

# 2. Set image name for the job template
# [START hypercomputer_gpu_tune_gemma4_multihost_gke_set_image_url]
IMAGE_REGISTRY="${ARTIFACT_REPO_LOCATION}-docker.pkg.dev/${PROJECT_ID}"
export IMAGE_URL="${IMAGE_REGISTRY}/gemma/finetune-gemma-multihost-gpu:2.0.0"
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_set_image_url]

# 3. Deploy JobSet
# Pre-flight: verify the JobSet admission webhook answers reliably before the
# real apply. During Cloud Build, Autopilot RESIZE_CLUSTER can scale down nodes
# running konnectivity-agent and cause transient 10s webhook timeouts.
echo "Verifying JobSet admission webhook with a server-side dry run..."
WEBHOOK_READY=false
LAST_ERROR=""
for attempt in $(seq 1 30); do
    if DRY_RUN_ERR=$(envsubst '${RESERVATION} ${IMAGE_URL} ${NUM_NODES}' < finetune.yaml \
        | kubectl apply --dry-run=server -f - 2>&1 >/dev/null); then
        echo "JobSet admission webhook is ready."
        WEBHOOK_READY=true
        break
    fi
    LAST_ERROR="${DRY_RUN_ERR}"
    echo "  JobSet webhook not ready yet (attempt ${attempt}/30), retrying in 10s..."
    sleep 10
done

if [[ "${WEBHOOK_READY}" != "true" ]]; then
    echo "Error: JobSet admission webhook did not become ready in time." >&2
    if [[ -n "${LAST_ERROR}" ]]; then
        echo "Last error: ${LAST_ERROR}" >&2
    fi
    exit 1
fi

# Retry apply on transient webhook disruptions occurring after pre-flight.
DEPLOY_SUCCEEDED=false
for attempt in $(seq 1 5); do
    set +e
# [START hypercomputer_gpu_tune_gemma4_multihost_gke_deploy_job]
envsubst '${RESERVATION} ${IMAGE_URL} ${NUM_NODES}' < finetune.yaml \
    | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_deploy_job]
    APPLY_RC=$?
    set -e
    if [[ "${APPLY_RC}" -eq 0 ]]; then
        DEPLOY_SUCCEEDED=true
        break
    fi
    echo "  kubectl apply failed with exit code ${APPLY_RC} (attempt ${attempt}/5), retrying in 15s..." >&2
    sleep 15
done

if [[ "${DEPLOY_SUCCEEDED}" != "true" ]]; then
    echo "Error: failed to deploy JobSet after 5 attempts." >&2
    exit 1
fi
echo "[$(date)] ==================== JobSet deployed. ===================="

# 4. Monitor JobSet and Verify Logs
declare -r JOBSET_NAME="finetune-jobset"
declare -r JOB_NAME="finetune-jobset-workers-0"
declare -r WAIT_TIMEOUT_SECONDS=14400
declare -r POLL_INTERVAL_SECONDS=30

dump_jobset_diagnostics() {
    echo "Fetching JobSet, Job, Pod status, events, and logs..."
    kubectl describe jobset "${JOBSET_NAME}" || true
    kubectl describe job "${JOB_NAME}" || true
    kubectl describe pods -l "jobset.sigs.k8s.io/jobset-name=${JOBSET_NAME}" || true
    kubectl get events --sort-by='.lastTimestamp' || true
    kubectl logs -l "job-name=${JOB_NAME}" --prefix=true --tail=200 || true
}

echo "Waiting for JobSet ${JOBSET_NAME} to create Job ${JOB_NAME}..."
JOB_CREATED=false
for attempt in $(seq 1 60); do
    if kubectl get job "${JOB_NAME}" &>/dev/null; then
        JOB_CREATED=true
        break
    fi
    echo "  Job not found yet (attempt ${attempt}/60), retrying in 5s..."
    sleep 5
done

if [[ "${JOB_CREATED}" != "true" ]]; then
    echo "Error: Job ${JOB_NAME} was not created within 300s." >&2
    dump_jobset_diagnostics
    exit 1
fi

echo "Waiting for JobSet ${JOBSET_NAME} to complete (timeout: ${WAIT_TIMEOUT_SECONDS}s)..."
WAIT_START_SECONDS="${SECONDS}"
while true; do
    COMPLETED_STATUS=$(kubectl get jobset "${JOBSET_NAME}" \
        -o jsonpath='{.status.conditions[?(@.type=="Completed")].status}' 2>/dev/null || true)
    if [[ "${COMPLETED_STATUS}" == "True" ]]; then
        break
    fi

    FAILED_STATUS=$(kubectl get jobset "${JOBSET_NAME}" \
        -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)
    if [[ "${FAILED_STATUS}" == "True" ]]; then
        FAILED_MSG=$(kubectl get jobset "${JOBSET_NAME}" \
            -o jsonpath='{.status.conditions[?(@.type=="Failed")].message}' 2>/dev/null || true)
        echo "Error: JobSet ${JOBSET_NAME} failed${FAILED_MSG:+: ${FAILED_MSG}}." >&2
        dump_jobset_diagnostics
        exit 1
    fi

    ELAPSED_SECONDS=$(( SECONDS - WAIT_START_SECONDS ))
    if (( ELAPSED_SECONDS >= WAIT_TIMEOUT_SECONDS )); then
        echo "Error: timed out after ${WAIT_TIMEOUT_SECONDS}s waiting for JobSet ${JOBSET_NAME} to complete." >&2
        dump_jobset_diagnostics
        exit 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
done

echo "[$(date)] ==================== JobSet completed. ===================="

