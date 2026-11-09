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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/kubernetes-engine-samples"
RAY_CLUSTER_NAME="ray-cluster-kuberay"

mkdir -p "${SCRIPT_DIR}/.tools"
export PATH="${SCRIPT_DIR}/.tools:${PATH}"

if [[ "${GPU_TYPE}" == "nvidia-b200" ]]; then
    NEW_TUNER_PATH="/usr/local/gib/configs/tuner_config_a4.txtpb"
elif [[ "${GPU_TYPE}" == "nvidia-h200-141gb" ]]; then
    NEW_TUNER_PATH="/usr/local/gib/configs/tuner_config_a3u.txtpb"
else
    echo "Error: Unsupported GPU_TYPE: ${GPU_TYPE}" >&2
    exit 1
fi

# Check and install Helm if not present
if ! command -v helm &> /dev/null; then
    HELM_VERSION="v3.22.1"
    echo "[$(date)] Helm not found. Installing Helm ${HELM_VERSION}..."
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
        | tar -xzf - -C "${SCRIPT_DIR}/.tools" --strip-components=1 linux-amd64/helm
else
    echo "Helm is already installed."
fi

# Install kubectl-ray plugin if not present
if ! kubectl ray version &> /dev/null; then
    echo "Installing kubectl ray plugin..."
    # [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_kubectl_ray_plugin_install]
    KUBECTL_RAY_VERSION="v1.3.2"
    mkdir -p .tools
    curl -fsSL "https://github.com/ray-project/kuberay/releases/download/${KUBECTL_RAY_VERSION}/kubectl-ray_${KUBECTL_RAY_VERSION}_linux_amd64.tar.gz" \
        | tar -xzf - -C .tools kubectl-ray
    export PATH="${PWD}/.tools:${PATH}"
    # [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_kubectl_ray_plugin_install]
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Cloning kubernetes-engine-samples into ${TARGET_DIR}..."
  git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples.git "${TARGET_DIR}"
  # Check out a fixed commit of the repository to avoid breaking changes
  git -C "${TARGET_DIR}" -c advice.detachedHead=false checkout "${NEMO_RL_CHART_COMMIT}"
else
  echo "Directory ${TARGET_DIR} already exists. Skipping clone."
fi

cd "${TARGET_DIR}/ai-ml/nemo-rl-on-gke/nemoRL"

# Replace NCCL_TUNER_CONFIG_PATH in values.yaml
sed -i "/- name: NCCL_TUNER_CONFIG_PATH/{n;s|value: \".*\"|value: \"${NEW_TUNER_PATH}\"|}" values.yaml
if ! grep -qF "value: \"${NEW_TUNER_PATH}\"" values.yaml; then
    echo "Error: Could not set NCCL_TUNER_CONFIG_PATH in values.yaml." >&2
    exit 1
fi

echo "[$(date)] ========== Deploying the Ray cluster... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_ray_cluster_deploy]
helm install ray-cluster . \
  --set image.tag="${NEMO_RL_VERSION}" \
  --set additionalWorkerGroups.worker-grp-0.replicas="${NUM_GPU_NODES}" \
  --set-string "additionalWorkerGroups.worker-grp-0.nodeSelector.cloud\.google\.com/gke-accelerator=${GPU_TYPE}" \
  --set head.resources.requests.cpu=12 \
  --set head.resources.requests.memory=96Gi \
  --set head.resources.limits.cpu=12 \
  --set head.resources.limits.memory=96Gi
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_ray_cluster_deploy]

EXPECTED_PODS=$((NUM_GPU_NODES + 1))
echo "[$(date)] ========== Waiting for ${EXPECTED_PODS} Ray cluster pods to be running and ready... =========="
count=0
LIMIT=360
while true; do
  READY_PODS=$(kubectl get pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" \
      -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
      | grep -c '^True$' || true)
  if [[ "${READY_PODS}" -ge "${EXPECTED_PODS}" ]]; then
    break
  fi
  if [[ ${count} -ge ${LIMIT} ]]; then
    echo "Error: Timeout waiting for the Ray cluster pods (${READY_PODS}/${EXPECTED_PODS} ready)." >&2
    kubectl get pods -o wide || true
    kubectl describe pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" | tail -n 100 || true
    kubectl get events --sort-by=.lastTimestamp | tail -n 50 || true
    exit 1
  fi
  if (( count % 30 == 0 )); then
    echo "[$(date)] ${READY_PODS}/${EXPECTED_PODS} Ray cluster pods ready."
  fi
  sleep 10
  count=$((count + 1))
done

echo "[$(date)] ========== Verifying the worker and head nodes... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_nodes_verify]
kubectl get pods
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_nodes_verify]

echo "[$(date)] ========== Verifying the Ray cluster... =========="
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_cluster_verify]
kubectl ray get cluster
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_cluster_verify]

echo "[$(date)] ========== Verifying the GPU driver version... =========="
WORKER_POD="$(kubectl get pods -l "ray.io/cluster=${RAY_CLUSTER_NAME},ray.io/node-type=worker" \
    -o jsonpath='{.items[0].metadata.name}')"
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_gpu_driver_verify]
kubectl exec "${WORKER_POD}" -c ray-worker -- \
    /usr/local/nvidia/bin/nvidia-smi --query-gpu=name,driver_version --format=csv
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_gpu_driver_verify]
DRIVER_VERSION="$(kubectl exec "${WORKER_POD}" -c ray-worker -- \
    /usr/local/nvidia/bin/nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)"
if [[ ! "${DRIVER_VERSION}" =~ ^[0-9]+ ]] || (( ${DRIVER_VERSION%%.*} < 580 )); then
    echo "Error: NVIDIA driver '${DRIVER_VERSION}' is older than R580, which the CUDA 13 image needs." >&2
    echo "Use a newer GKE_VERSION or set GPU_DRIVER_VERSION to latest." >&2
    exit 1
fi
echo "NVIDIA driver ${DRIVER_VERSION} meets the R580 minimum."
