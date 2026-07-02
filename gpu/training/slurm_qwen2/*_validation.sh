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
# Step 1: Identify login node
# -------------------------------------------------------------------------
echo -e "\n--- [Step 1] Identifying Slurm Login Node ---"

# Checking and assigning PROJECT_ID to an internal variable
ENV_PROJECT="${PROJECT_ID:-}"
if [ -z "${ENV_PROJECT}" ]; then
    ENV_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
fi

# Dynamic search for the Login Node
if [ -z "${LOGIN_NODE:-}" ] && [ -n "${ENV_PROJECT}" ]; then
    LOGIN_NODE=$(gcloud compute instances list \
        --project="${ENV_PROJECT}" \
        --filter="name:login AND status:RUNNING" \
        --format="value(name)" \
        --limit=1 2>/dev/null || echo "")
fi

if [ -z "${LOGIN_NODE:-}" ]; then
    log_error "Active Login Node could not be found. PROJECT_ID is: ${ENV_PROJECT:-NOT_SET}."
    exit 1
fi

log_info "Active Login Node detected: ${LOGIN_NODE}"


# -------------------------------------------------------------------------
# Step 2: Fetch all slurm logs from login node
# -------------------------------------------------------------------------
echo -e "\n--- [Step 2] Fetching Slurm Logs from Cluster ---"
log_info "Downloading slurm log files from ~/logs/ to local directory: ${LOCAL_LOGS_DIR}..."

gcloud compute scp \
    --project="${ENV_PROJECT}" \
    --zone="${ZONE:-us-west3-c}" \
    --tunnel-through-iap \
    "${LOGIN_NODE}:~/logs/slurm-*" "${LOCAL_LOGS_DIR}/"

# Verification of the retrieved files (.out or .err)
DOWNLOADED_LOGS=( "${LOCAL_LOGS_DIR}"/slurm-* )
if [ ! -e "${DOWNLOADED_LOGS[0]}" ]; then
    log_warn "No slurm log files found in ${LOCAL_LOGS_DIR}."
    log_warn "Please ensure that the job was submitted and logs are in ~/logs/ directory."
    exit 1
fi

log_info "Successfully downloaded log files:"
ls -l "${LOCAL_LOGS_DIR}"/slurm-* | sed 's/^/  /'


# -------------------------------------------------------------------------
# Step 3: Assert successful training
# -------------------------------------------------------------------------
echo -e "\n--- [Step 3] Analyzing Log File and Asserting Success ---"

# Retrieve the latest .out output file for analysis
LATEST_LOG=$(ls -t "${LOCAL_LOGS_DIR}"/slurm-*.out | head -n 1)
log_info "Analyzing the latest log file: ${LATEST_LOG}"

SUCCESS_MARKER="Training finished\|Saving final model"
ERROR_MARKER="OOM\|Out of memory\|CUDA error\|Traceback\|Error\|Segmentation fault"

# 1. Error Check
if grep -qi "${ERROR_MARKER}" "${LATEST_LOG}"; then
    log_error "Critical errors or GPU memory issues (OOM) detected in the output log!"
    echo "--------------------------------------------------------"
    grep -in -C 2 "${ERROR_MARKER}" "${LATEST_LOG}" | sed 's/^/  /'
    echo "--------------------------------------------------------"
    exit 1
fi

# 2. Check if the model saved its outputs (Assert Success)
if grep -qi "${SUCCESS_MARKER}" "${LATEST_LOG}"; then
    echo "========================================================================="
    log_info "ASSERT PASSED: Training completed successfully!"
    log_info "Detected successful saving of model weights and no GPU errors."
    echo "Last lines of the log file:"
    tail -n 5 "${LATEST_LOG}" | sed 's/^/  /'
    echo "========================================================================="
    exit 0
else
    log_warn "ASSERT FAILED: The training job might still be running or hasn't saved weights yet."
    log_warn "Completion/saving signature was not found in the log file."
    echo "Last lines of the log file:"
    tail -n 5 "${LATEST_LOG}" | sed 's/^/  /'
    exit 1
fi
# [END hypercomputer_gpu_train_qwen2_slurm_validation]
