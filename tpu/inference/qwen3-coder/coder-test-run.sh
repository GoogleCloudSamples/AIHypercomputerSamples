#!/bin/bash
set -e

SAMPLE_DIR="/usr/local/google/home/kirylf/workingrepos/github/AIHypercomputerSamples/tpu/inference/qwen3-coder"
LOG_DIR="/usr/local/google/home/kirylf/workingrepos/573056763_new_content_tpu_v7x_v6e_Qwen3_Coder_multi-host/logs_for_share"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/coder-test-run-$(date +%Y%m%d-%H%M%S).log"

echo -n "Enter your Hugging Face Token (HF_TOKEN): "
read -s HF_TOKEN_INPUT
echo

exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Logging output to: ${LOG_FILE}"

cd "${SAMPLE_DIR}"

# Create temp dir for fake 0_env
TEMP_ENV_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_ENV_DIR}"' EXIT

# Create fake 0_env.sh
cat <<EOF > "${TEMP_ENV_DIR}/0_env.sh"
export CLUSTER_NAME="${USER}-cuj004"
export PROJECT_ID="dx-supercomputer-testing"
export REGION="us-central1"
export ZONE="us-central1-c"
export SGLANG_IMAGE="us-central1-docker.pkg.dev/hdx-ext-uxr/test-images/sglang-torchtpu:latest"

gcloud config set project "\${PROJECT_ID}"
gcloud config set billing/quota_project "\${PROJECT_ID}"
gcloud auth application-default set-quota-project "\${PROJECT_ID}"
echo "Sourced FAKE 0_env.sh from \${TEMP_ENV_DIR}"
EOF

echo "export HF_TOKEN=\"${HF_TOKEN_INPUT}\"" >> "${TEMP_ENV_DIR}/0_env.sh"

# Source the fake 0_env.sh to export variables to this script's environment
source "${TEMP_ENV_DIR}/0_env.sh"

# Make sure the files are executable before running
chmod +x ./*.sh

echo "=== Starting Sequence ==="
./1_setup.sh
./2_run_inference.sh
./3_run_benchmark.sh

echo "=== Running Validation ==="
./*_validation.sh

echo "=== Cleaning Up ==="
./cleanup.sh
echo "=== Sequence Completed ==="
