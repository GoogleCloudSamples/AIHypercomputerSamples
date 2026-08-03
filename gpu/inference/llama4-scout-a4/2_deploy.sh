#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR}/gpu-recipes"
export RECIPE_ROOT="${REPO_ROOT}/inference/a4/single-host-serving"

# 1. Create GKE cluster (if not existing)
echo "--------------------------------------------------------"
echo "Step 1: Creating GKE Cluster and Node Pool for B200 (A4)"
echo "--------------------------------------------------------"

if gcloud container clusters describe "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✓ Cluster '$CLUSTER_NAME' already exists."
else
    echo "Creating GKE cluster..."
    gcloud container clusters create "${CLUSTER_NAME}" \
        --project="${PROJECT_ID}" \
        --region="${CLUSTER_REGION}" \
        --release-channel="stable" \
        --num-nodes=1 \
        --machine-type="e2-standard-4" \
        --workload-pool="${PROJECT_ID}.svc.id.goog" \
        --addons=GcsFuseCsiDriver \
        --logging=SYSTEM,WORKLOAD \
        --monitoring=SYSTEM \
        --quiet
fi

# 2. Create A4 GPU node pool with 8x B200 GPUs
if gcloud container node-pools describe "$NODE_POOL_NAME" --cluster "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✓ Node pool '$NODE_POOL_NAME' already exists."
else
    echo "Creating node pool with 8x B200 GPUs (A4)..."
    gcloud container node-pools create "$NODE_POOL_NAME" \
        --cluster="${CLUSTER_NAME}" \
        --region="${CLUSTER_REGION}" \
        --node-locations="${ZONE}" \
        --project="${PROJECT_ID}" \
        --machine-type="a4-highgpu-8g" \
        --accelerator=type=nvidia-b200,count=8,gpu-driver-version=default \
        --num-nodes=1 \
        --reservation-affinity=specific \
        --reservation="${RESERVATION}" \
        --enable-gvnic \
        --quiet
fi

# 3. Fetch cluster credentials for kubectl
echo "Fetching cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "${PROJECT_ID}"

echo "✓ Cluster setup completed."

# 4. Build custom Docker image with Cloud Build
echo "--------------------------------------------------------"
echo "Step 2 & 3: Direct Docker Build for B200 (sm_100)"
echo "--------------------------------------------------------"

BUILD_DIR="${SCRIPT_DIR}/build_b200"
mkdir -p "${BUILD_DIR}"

cat <<EOF > "${BUILD_DIR}/Dockerfile"
FROM vllm/vllm-openai:${BASE_TAG}

ENV PYTHONUNBUFFERED=1
ENV TORCH_CUDA_ARCH_LIST="10.0"
ENV HF_HUB_ENABLE_HF_TRANSFER=1

RUN ln -sf /usr/bin/python3 /usr/bin/python || true
RUN python3 -m pip install --no-cache-dir hf_transfer pyyaml
EOF

FULL_IMAGE_NAME="${ARTIFACT_REGISTRY}/${VLLM_IMAGE}:${VLLM_VERSION}"
echo "Submitting direct Cloud Build (synchronous wait) for: ${FULL_IMAGE_NAME}..."

gcloud builds submit "${BUILD_DIR}" \
    --tag="${FULL_IMAGE_NAME}" \
    --region="${REGION}" \
    --timeout="2h" \
    --machine-type=e2-highcpu-32 \
    --disk-size=1000

echo "✓ Docker image successfully built and pushed to Artifact Registry:"
echo "  ${FULL_IMAGE_NAME}"

# 5. Create Hugging Face Kubernetes secret
echo "--------------------------------------------------------"
echo "Step 4: Creating Kubernetes Secret for Hugging Face"
echo "--------------------------------------------------------"

if [ -z "${HF_TOKEN:-}" ]; then
    echo "ERROR: HF_TOKEN is not set in 0_env.sh"
    exit 1
fi

kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret 'hf-secret' applied."

# 6. Deploy Llama 4 serving workload via Helm
echo "--------------------------------------------------------"
echo "Step 5 & 6: Deploying Llama 4 on B200 (A4 Native Chart)"
echo "--------------------------------------------------------"

RELEASE_NAME="${USER}-serving-llama-4-a4"
CHART_PATH="${REPO_ROOT}/src/helm-charts/a4/inference-templates/deployment"
VALUES_FILE="${REPO_ROOT}/inference/a4/single-host-serving/vllm/values.yaml"
TARGET_MODEL="${MODEL_ID}"

echo "Installing Helm chart release: ${RELEASE_NAME}"
echo "Model: ${TARGET_MODEL}"

# 8. Install Helm release
helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
    -f "${VALUES_FILE}" \
    --set volumes.gcsMounts[0].bucketName="${GCS_BUCKET}" \
    --set volumes.gcsMounts[0].mountPath="/gcs" \
    --set volumes.ssdMountPath="/tmp" \
    --set workload.model.name="${TARGET_MODEL}" \
    --set workload.image="${FULL_IMAGE_NAME}" \
    --set workload.gpus=8 \
    --set workload.configFile="" \
    --set workload.configPath="" \
    --set service.type=ClusterIP \
    --set service.ports.http=8000 \
    --set network.gibVersion=""

# 9. Apply customized B200 workload launcher ConfigMap
echo "Applying B200 launcher ConfigMap..."
SCRIPT_CONTENT='#!/bin/bash
if [[ -n "${NCCL_INIT_SCRIPT}" ]]; then
  echo "Running NCCL init script: ${NCCL_INIT_SCRIPT}"
  source ${NCCL_INIT_SCRIPT}
fi

# Disable gIB for single-node setups (pure NVLink)
unset NCCL_NET
unset NCCL_PLUGIN_PATH

# Environment flags optimized for B200 (sm_100 / Blackwell)
export TORCH_CUDA_ARCH_LIST="10.0"
export VLLM_DISABLE_CUSTOM_ALL_REDUCE=1
export VLLM_USE_V1=0
export VLLM_NCCL_SO_PATH=""
export NCCL_IB_DISABLE=1
export NCCL_NET_GDR_LEVEL=0
export NCCL_P2P_DISABLE=0
export NCCL_DEBUG=WARN
export HF_HOME="/tmp/hf_home"

MODEL="'"${TARGET_MODEL}"'"

echo "Starting vLLM OpenAI API Server via python3 for model: ${MODEL}..."
exec python3 -m vllm.entrypoints.openai.api_server \
  --model "${MODEL}" \
  --tensor-parallel-size 8 \
  --pipeline-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --enforce-eager \
  --trust-remote-code
'

kubectl create configmap "${RELEASE_NAME}-launcher" \
    --from-literal=launch-workload.sh="${SCRIPT_CONTENT}" \
    --dry-run=client -o yaml | \
kubectl label --local -f - "app.kubernetes.io/managed-by=Helm" -o yaml | \
kubectl annotate --local -f - "meta.helm.sh/release-name=${RELEASE_NAME}" "meta.helm.sh/release-namespace=default" -o yaml | \
kubectl apply -f -

echo "--------------------------------------------------------"
echo "Deployment submitted! Check pods using:"
echo "  kubectl get pods -w"
echo "--------------------------------------------------------"
