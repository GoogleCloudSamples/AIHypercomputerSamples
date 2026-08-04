#!/bin/bash
set -e

echo -n "Enter your Hugging Face Token (HF_TOKEN): "
read -s HF_TOKEN_INPUT
echo

# Create temp dir for fake 0_env
TEMP_ENV_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_ENV_DIR}"' EXIT

# Create fake 0_env.sh
cat <<EOF > "${TEMP_ENV_DIR}/0_env.sh"
export PROJECT="dx-supercomputer-testing"
export REGION="europe-west4"
export ZONE="europe-west4-a"
export CLUSTER_NAME="gke-tpu-v6e"
export GCS_BUCKET="kirylf-qwen-gcluster-bucket-test"
export REPOSITORY_NAME="maxtext-images-kirylf-test"
export CLOUD_IMAGE_NAME="\${REGION}-docker.pkg.dev/\${PROJECT}/\${REPOSITORY_NAME}/maxtext_base:latest"
export TPU_TYPE="v6e-32"
export MODEL_NAME="qwen3-14b"
export RESERVATION="happy-tpus"

gcloud config set project "\${PROJECT}"
echo "Sourced FAKE 0_env.sh from \${TEMP_ENV_DIR}"
EOF

echo "export HF_TOKEN=\"${HF_TOKEN_INPUT}\"" >> "${TEMP_ENV_DIR}/0_env.sh"

# Source the fake 0_env.sh to export variables to this script's environment
source "${TEMP_ENV_DIR}/0_env.sh"

# Make sure the files are executable before running
chmod +x ./1_build_image.sh
chmod +x ./2_setup_cluster.sh
chmod +x ./3_convert_model.sh
chmod +x ./4_train_model.sh
chmod +x ./5_convert_model_hf.sh
chmod +x ./6_cleanup.sh

echo "=== Starting Sequence ==="
./1_build_image.sh
./2_setup_cluster.sh
./3_convert_model.sh
./4_train_model.sh
./5_convert_model_hf.sh
./6_cleanup.sh
echo "=== Sequence Completed ==="
