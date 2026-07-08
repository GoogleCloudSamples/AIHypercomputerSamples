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

# =========================================================================
# Qwen2 Slurm Workload Validation Script
# =========================================================================

# [START hypercomputer_gpu_train_qwen2_slurm_validation]
set -euo pipefail

LOCAL_LOGS_DIR="./slurm_logs_fetch"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} ${1}"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} ${1}"; }
log_error() { echo -e "${RED}[ERROR]${NC} ${1}"; }

mkdir -p "${LOCAL_LOGS_DIR}"

echo "========================================================================="
echo " Starting Workload Validation for Qwen2 Training Pipeline"
echo "========================================================================="

# -------------------------------------------------------------------------
# Step 1: Identify project, zone, and login node
# -------------------------------------------------------------------------
echo -e "\n--- [Step 1] Identifying Cluster Infrastructure Parameters ---"

# Dynamic assignment and verification of PROJECT_ID
ENV_PROJECT="${PROJECT_ID:-}"
if [ -z "${ENV_PROJECT}" ]; then
    ENV_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
fi

if [ -z "${ENV_PROJECT}" ]; then
    log_error "PROJECT_ID could not be determined. Please run 'gcloud config set project' or export PROJECT_ID."
    exit 1
fi

# Automatic zone detection
ENV_ZONE="${ZONE:-}"
if [ -z "${ENV_ZONE}" ]; then
    ENV_ZONE=$(gcloud config get-value compute/zone 2>/dev/null || echo "")
fi

# Dynamic zone lookup based on the active login node if the above fails
if [ -z "${ENV_ZONE}" ]; then
    ENV_ZONE=$(gcloud compute instances list \
        --project="${ENV_PROJECT}" \
        --filter="name:login" \
        --format="value(zone)" \
        --limit=1 2>/dev/null || echo "")
fi

if [ -z "${ENV_ZONE}" ]; then
    log_error "Could not automatically determine GCP ZONE. Please export ZONE=your-cluster-zone."
    exit 1
fi

# Dynamic lookup of the Login Node name
if [ -z "${LOGIN_NODE:-}" ]; then
    LOGIN_NODE=$(gcloud compute instances list \
        --project="${ENV_PROJECT}" \
        --filter="name:login AND status:RUNNING" \
        --format="value(name)" \
        --limit=1 2>/dev/null || echo "")
fi

if [ -z "${LOGIN_NODE}" ]; then
    log_error "Active Login Node could not be found in project: ${ENV_PROJECT}."
    exit 1
fi

log_info "Active Project: ${ENV_PROJECT}"
log_info "Active Zone:    ${ENV_ZONE}"
log_info "Login Node:     ${LOGIN_NODE}"


# -------------------------------------------------------------------------
# Step 2: Fetch only the active/latest slurm log from login node
# -------------------------------------------------------------------------
echo -e "\n--- [Step 2] Fetching the Active Slurm Log from Cluster ---"

log_info "Querying cluster for the active or most recent Job ID..."
# ID of the user's latest active job
ACTIVE_JOB_ID=$(gcloud compute ssh "${LOGIN_NODE}" \
    --project="${ENV_PROJECT}" \
    --zone="${ENV_ZONE}" \
    --tunnel-through-iap \
    --command="squeue -u \$USER -t RUNNING,PENDING -o %A | tail -n 1" 2>/dev/null || echo "")

if [ -z "${ACTIVE_JOB_ID}" ]; then
    log_warn "No running job found. Looking for the last completed job ID..."
    ACTIVE_JOB_ID=$(gcloud compute ssh "${LOGIN_NODE}" \
        --project="${ENV_PROJECT}" \
        --zone="${ENV_ZONE}" \
        --tunnel-through-iap \
        --command="ls ~/logs/slurm-*.out 2>/dev/null | awk -F'-' '{print \$2}' | awk -F'.' '{print \$1}' | sort -n | tail -n 1" 2>/dev/null || echo "")
fi

if [ -z "${ACTIVE_JOB_ID}" ]; then
    log_error "Could not find any Slurm job logs on the remote cluster."
    exit 1
fi

log_info "Targeting Job ID: ${ACTIVE_JOB_ID}"
log_info "Downloading slurm-${ACTIVE_JOB_ID}.* to local directory..."

gcloud compute scp \
    --project="${ENV_PROJECT}" \
    --zone="${ENV_ZONE}" \
    --tunnel-through-iap \
    "${LOGIN_NODE}:~/logs/slurm-${ACTIVE_JOB_ID}.*" "${LOCAL_LOGS_DIR}/"

# -------------------------------------------------------------------------
# Step 3: Assert successful training
# -------------------------------------------------------------------------
echo -e "\n--- [Step 3] Analyzing Log File and Asserting Success ---"

LATEST_LOG="${LOCAL_LOGS_DIR}/slurm-${ACTIVE_JOB_ID}.out"
log_info "Analyzing log file: ${LATEST_LOG}"

# Define success markers (logging loss/step metrics or successful completion))
SUCCESS_MARKER="\"loss\":\|step:\|Training finished\|Saving final model"

CLEANED_LOG_FLOW=$(grep -v "NCCL INFO" "${LATEST_LOG}")

# 1. Checking for critical errors hidden in the raw data stream
if echo "${CLEANED_LOG_FLOW}" | grep -qi "OutOfMemoryError\|CUDA error\|Traceback\|Segmentation fault\|FAILED\|Duplicate GPU"; then
    log_error "Critical errors or GPU memory issues (OOM) detected in the output log!"
    echo "--------------------------------------------------------"
    echo "${CLEANED_LOG_FLOW}" | grep -i -C 2 "OutOfMemoryError\|CUDA error\|Traceback\|Segmentation fault\|FAILED\|Duplicate GPU" | head -n 30 | sed 's/^/  /'
    echo "--------------------------------------------------------"
    exit 1
fi

# 2.Checking training progress (Assert Success)
if echo "${CLEANED_LOG_FLOW}" | grep -qi "${SUCCESS_MARKER}"; then
    echo "========================================================================="
    log_info "ASSERT PASSED: Training is progressing or completed successfully!"
    log_info "Detected active training steps/loss metrics and no GPU crashes."
    echo "Last active training lines of the log file (excluding NCCL noise):"
    echo "${CLEANED_LOG_FLOW}" | tail -n 10 | sed 's/^/  /'
    echo "========================================================================="
    exit 0
else
    log_warn "ASSERT FAILED: The training job initialized, but no training steps or loss values were recorded yet."
    log_warn "Model might still be compiling layers or initializing communication weights."
    echo "Last lines of the log file:"
    tail -n 5 "${LATEST_LOG}" | sed 's/^/  /'
    exit 1
fi
# [END hypercomputer_gpu_train_qwen2_slurm_validation]
