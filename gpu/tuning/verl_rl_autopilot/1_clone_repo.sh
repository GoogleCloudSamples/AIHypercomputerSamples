#!/bin/bash

source 0_env.sh

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/kubernetes-engine-samples"

if [ ! -d "${TARGET_DIR}" ]; then
  echo "Cloning kubernetes-engine-samples into ${TARGET_DIR}..."
  git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples.git "${TARGET_DIR}"
else
  echo "Directory ${TARGET_DIR} already exists. Skipping clone."
fi

echo "kubernetes-engine-samples cloned."
