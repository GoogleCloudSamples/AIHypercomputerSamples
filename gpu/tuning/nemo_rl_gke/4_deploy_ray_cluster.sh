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

# Check and install Helm if not present
if ! command -v helm &> /dev/null; then
    echo "[$(date)] Helm not found. Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm is already installed."
fi

# Install kubectl-ray plugin if not present
if ! kubectl ray version &> /dev/null; then
    echo "Installing kubectl ray plugin..."
    KUBECTL_RAY_VERSION="v1.3.2"
    curl -LO "https://github.com/ray-project/kuberay/releases/download/${KUBECTL_RAY_VERSION}/kubectl-ray_${KUBECTL_RAY_VERSION}_linux_amd64.tar.gz"
    tar -xvf "kubectl-ray_${KUBECTL_RAY_VERSION}_linux_amd64.tar.gz"
    sudo cp kubectl-ray /usr/local/bin/
    sudo chmod +x /usr/local/bin/kubectl-ray
    rm -f "kubectl-ray_${KUBECTL_RAY_VERSION}_linux_amd64.tar.gz" kubectl-ray
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/kubernetes-engine-samples"

if [ ! -d "${TARGET_DIR}" ]; then
  echo "Cloning kubernetes-engine-samples into ${TARGET_DIR}..."
  git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples.git "${TARGET_DIR}"
  # Checkout specific version of the repository to avoid breaking changes
  git -C "${TARGET_DIR}" checkout 87fa0575c977b96f6d3af2cab58c9128f3cf0dc3
else
  echo "Directory ${TARGET_DIR} already exists. Skipping clone."
fi

cd "${TARGET_DIR}/ai-ml/nemo-rl-on-gke/nemoRL"

# Set NCCL_TUNER_CONFIG_PATH based on GPU type
if [ "${GPU_TYPE}" == "nvidia-b200" ]; then
    NEW_TUNER_PATH="/usr/local/gib/configs/tuner_config_a4.txtpb"
elif [ "${GPU_TYPE}" == "nvidia-h200-141gb" ]; then
    NEW_TUNER_PATH="/usr/local/gib/configs/tuner_config_a3u.txtpb"
else
    echo "Error: Unsupported GPU_TYPE: ${GPU_TYPE}" >&2
    exit 1
fi

# Replace NCCL_TUNER_CONFIG_PATH in values.yaml
sed -i "/- name: NCCL_TUNER_CONFIG_PATH/{n;s|value: \".*\"|value: \"${NEW_TUNER_PATH}\"|}" values.yaml

echo "[$(date)] ========== Deploying the Ray cluster... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_ray_cluster_deploy]
export REPLICA_COUNT=2
helm install ray-cluster . \
  --set additionalWorkerGroups.worker-grp-0.replicas=$REPLICA_COUNT
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_ray_cluster_deploy]

sleep 10
echo "[$(date)] ========== Waiting for all Ray cluster pods to be running and ready... =========="
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=kuberay --timeout=900s

echo "[$(date)] ========== Verifying the worker and head nodes... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_nodes_verify]
kubectl get pods
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_nodes_verify]

echo "[$(date)] ========== Verifying the Ray cluster... =========="
# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_cluster_verify]
kubectl ray get cluster
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_cluster_verify]