#!/bin/bash
#
#   Copyright 2026 Google LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail

RAY_JOB_NAME="gemma4-tuning-job"
RAY_CLUSTER_NAME="gemma4-tuning"
TRAINING_LOG="$(mktemp)"

dump_debug_info() {
    echo "==================== Debug information ===================="
    kubectl describe rayjob "${RAY_JOB_NAME}" || true
    echo "---------- Ray job submitter logs (last 200 lines) ----------"
    kubectl logs "job/${RAY_JOB_NAME}" --tail=200 || true
    echo "---------- Ray pods ----------"
    kubectl get pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" -o wide || true
    echo "---------- Recent events ----------"
    kubectl get events --sort-by='.metadata.creationTimestamp' | tail -n 30 || true
}

on_exit() {
    local status=$?
    if [[ "${status}" -ne 0 ]]; then
        echo "[$(date)] Validation failed with exit code ${status}."
        dump_debug_info
    fi
    rm -f "${TRAINING_LOG}"
}
trap on_exit EXIT

echo "[$(date)] ==================== Starting validation ===================="

# 1. Wait for the training RayJob to finish
if ! kubectl get rayjob "${RAY_JOB_NAME}" > /dev/null; then
    echo "Error: RayJob '${RAY_JOB_NAME}' not found. Run ./2_deploy_model.sh first."
    exit 1
fi

TIMEOUT_SECONDS=5400
INTERVAL_SECONDS=60
ELAPSED_SECONDS=0
while true; do
    JOB_STATUS="$(kubectl get rayjob "${RAY_JOB_NAME}" \
        -o jsonpath='{.status.jobStatus}' 2> /dev/null || true)"
    DEPLOYMENT_STATUS="$(kubectl get rayjob "${RAY_JOB_NAME}" \
        -o jsonpath='{.status.jobDeploymentStatus}' 2> /dev/null || true)"
    if [[ "${JOB_STATUS}" == "SUCCEEDED" ]]; then
        break
    fi
    if [[ "${JOB_STATUS}" == "FAILED" || "${JOB_STATUS}" == "STOPPED" \
        || "${DEPLOYMENT_STATUS}" == "Failed" ]]; then
        echo "Error: RayJob '${RAY_JOB_NAME}' ended with jobStatus='${JOB_STATUS}'" \
            "and jobDeploymentStatus='${DEPLOYMENT_STATUS}'."
        exit 1
    fi
    if [[ "${ELAPSED_SECONDS}" -ge "${TIMEOUT_SECONDS}" ]]; then
        echo "Error: RayJob '${RAY_JOB_NAME}' did not finish within ${TIMEOUT_SECONDS}s."
        exit 1
    fi
    echo "RayJob status: jobStatus='${JOB_STATUS:-PENDING}'" \
        "jobDeploymentStatus='${DEPLOYMENT_STATUS:-Initializing}'" \
        "(${ELAPSED_SECONDS}/${TIMEOUT_SECONDS}s elapsed)..."
    sleep "${INTERVAL_SECONDS}"
    ELAPSED_SECONDS=$((ELAPSED_SECONDS + INTERVAL_SECONDS))
done
echo "[$(date)] RayJob '${RAY_JOB_NAME}' succeeded."

kubectl logs "job/${RAY_JOB_NAME}" > "${TRAINING_LOG}" 2>&1 || true
echo "Ray Train workers that reported 'Training finished.':" \
    "$(grep -c "Training finished." "${TRAINING_LOG}" || true)"
grep "Final checkpoint: " "${TRAINING_LOG}" \
    || echo "Warning: 'Final checkpoint:' not found in the submitter logs."

# 2. Validate the fine-tuned adapter
# [START hypercomputer_gpu_tune_gemma4_ray_validation]
LATEST_RUN="$(gcloud storage ls "gs://${GCS_BUCKET}/" --project="${PROJECT_ID}" \
    | grep "gemma4_vision_train_" | sort | tail -n 1 || true)"
if [[ -z "${LATEST_RUN}" ]]; then
    echo "Error: No training run found in gs://${GCS_BUCKET}."
    exit 1
fi

ADAPTER_FILE="$(gcloud storage ls "${LATEST_RUN}**/adapter_model.safetensors" \
    --project="${PROJECT_ID}" | sort | tail -n 1 || true)"
if [[ -z "${ADAPTER_FILE}" ]]; then
    echo "Error: No adapter_model.safetensors found under ${LATEST_RUN}."
    exit 1
fi
ADAPTER_URI="${ADAPTER_FILE%/adapter_model.safetensors}"
echo "Latest fine-tuned adapter: ${ADAPTER_URI}"

HEAD_POD="$(kubectl get pods -l ray.io/cluster=gemma4-tuning,ray.io/node-type=head \
    -o jsonpath='{.items[0].metadata.name}')"

kubectl get rayjob gemma4-tuning-job -o jsonpath='{.spec.runtimeEnvYAML}' \
    | kubectl exec -i "${HEAD_POD}" -c ray-head -- sh -c 'cat > /tmp/runtime_env.yaml'

VALIDATION_JOB_ID="gemma4-validate-$(date +%s)"
kubectl exec "${HEAD_POD}" -c ray-head -- ray job submit \
    --no-wait \
    --submission-id="${VALIDATION_JOB_ID}" \
    --entrypoint-num-gpus=1 \
    --entrypoint-num-cpus=4 \
    --runtime-env=/tmp/runtime_env.yaml \
    -- python /code/validate_adapter.py \
        --model_id "${MODEL_ID}" \
        --adapter_uri "${ADAPTER_URI}"
# [END hypercomputer_gpu_tune_gemma4_ray_validation]

get_validation_status() {
    kubectl exec "${HEAD_POD}" -c ray-head -- python -c \
        "from ray.job_submission import JobSubmissionClient; \
print(JobSubmissionClient('http://127.0.0.1:8265').get_job_status('${VALIDATION_JOB_ID}'))" \
        2> /dev/null | tail -n 1 | tr -d '\r' || true
}

TIMEOUT_SECONDS=1200
INTERVAL_SECONDS=15
ELAPSED_SECONDS=0
while true; do
    VALIDATION_STATUS="$(get_validation_status)"
    if [[ "${VALIDATION_STATUS}" == "SUCCEEDED" || "${VALIDATION_STATUS}" == "FAILED" \
        || "${VALIDATION_STATUS}" == "STOPPED" ]]; then
        break
    fi
    if [[ "${ELAPSED_SECONDS}" -ge "${TIMEOUT_SECONDS}" ]]; then
        echo "Error: Validation job '${VALIDATION_JOB_ID}' did not finish within ${TIMEOUT_SECONDS}s."
        exit 1
    fi
    echo "Validation job status: '${VALIDATION_STATUS:-UNKNOWN}' (${ELAPSED_SECONDS}/${TIMEOUT_SECONDS}s elapsed)..."
    sleep "${INTERVAL_SECONDS}"
    ELAPSED_SECONDS=$((ELAPSED_SECONDS + INTERVAL_SECONDS))
done

VALIDATION_LOG="$(mktemp)"
for attempt in 1 2 3 4 5; do
    if kubectl exec "${HEAD_POD}" -c ray-head -- \
        ray job logs "${VALIDATION_JOB_ID}" > "${VALIDATION_LOG}" 2>&1; then
        break
    fi
    echo "Retrying 'ray job logs' (attempt ${attempt}/5)..."
    sleep 5
done
grep -v -E "HTTP Request|Loading weights" "${VALIDATION_LOG}" || true

if [[ "${VALIDATION_STATUS}" != "SUCCEEDED" ]] \
    || ! grep -q "VALIDATION PASSED" "${VALIDATION_LOG}"; then
    echo "Error: Validation job '${VALIDATION_JOB_ID}' ended with status '${VALIDATION_STATUS}'" \
        "or did not report 'VALIDATION PASSED'."
    rm -f "${VALIDATION_LOG}"
    exit 1
fi
rm -f "${VALIDATION_LOG}"

echo "[$(date)] ==================== Validation succeeded ===================="
