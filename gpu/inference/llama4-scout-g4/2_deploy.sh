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
# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_recipes_repo]
export REPO_ROOT="${SCRIPT_DIR}/gpu-recipes"
export RECIPE_ROOT="${REPO_ROOT}/inference/a4/single-host-serving"
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_recipes_repo]

# 1. Create GKE cluster (if not existing)
echo "--------------------------------------------------------"
echo "Step 1: Creating GKE Cluster and Node Pool for RTX Pro 6000 (G4)"
echo "--------------------------------------------------------"

if gcloud container clusters describe "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✓ Cluster '$CLUSTER_NAME' already exists."
else
    echo "Creating GKE cluster..."
# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_cluster_create]
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
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_cluster_create]
fi

# 2. Create G4 node pool with 8x RTX Pro 6000 GPUs
if gcloud container node-pools describe "$NODE_POOL_NAME" --cluster "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✓ Node pool '$NODE_POOL_NAME' already exists."
else
    echo "Creating node pool with 8x RTX Pro 6000 GPUs (G4) and 32x Local SSDs..."
# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_node_pool_create]
    gcloud container node-pools create "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --region="${CLUSTER_REGION}" \
        --node-locations="${ZONE}" \
        --project="${PROJECT_ID}" \
        --machine-type="g4-standard-384" \
        --accelerator=type=nvidia-rtx-pro-6000,count=8,gpu-driver-version=default \
        --ephemeral-storage-local-ssd=count=32 \
        --num-nodes=1 \
        --reservation-affinity=specific \
        --reservation="${RESERVATION}" \
        --node-taints="cloud.google.com/gke-accelerator=nvidia-rtx-pro-6000:NoSchedule" \
        --quiet
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_node_pool_create]
fi

# 3. Fetch cluster credentials for kubectl
echo "Fetching cluster credentials..."
# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_fetch_cred]
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${CLUSTER_REGION}" --project "${PROJECT_ID}"
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_fetch_cred]

echo "✓ Cluster setup completed."

# 4. Build custom Docker image with Cloud Build
echo "--------------------------------------------------------"
echo "Step 2 & 3: Direct Docker Build for G4 (RTX Pro 6000)"
echo "--------------------------------------------------------"

# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_container_image_build]
BUILD_DIR="${SCRIPT_DIR}/build_rtx6000"
mkdir -p "${BUILD_DIR}"

cat <<EOF > "${BUILD_DIR}/Dockerfile"
FROM vllm/vllm-openai:${BASE_TAG}

ENV PYTHONUNBUFFERED=1
ENV TORCH_CUDA_ARCH_LIST="10.0"
ENV HF_HUB_ENABLE_HF_TRANSFER=1

RUN ln -sf /usr/bin/python3 /usr/bin/python || true
RUN python3 -m pip install --no-cache-dir hf_transfer pyyaml
EOF
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_container_image_build]

# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_ar_image]
FULL_IMAGE_NAME="${ARTIFACT_REGISTRY}/${VLLM_IMAGE}:${VLLM_VERSION}"
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_ar_image]
echo "Submitting direct Cloud Build (synchronous wait) for: ${FULL_IMAGE_NAME}..."

# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_gcloud_build]
gcloud builds submit "${BUILD_DIR}" \
    --tag="${FULL_IMAGE_NAME}" \
    --region="${REGION}" \
    --timeout="2h" \
    --machine-type=e2-highcpu-32 \
    --disk-size=1000
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_gcloud_build]

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

# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_create_hf_token]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_create_hf_token]

echo "✓ Secret 'hf-secret' applied."

# 6. Deploy Llama 4 serving workload via Helm
echo "--------------------------------------------------------"
echo "Step 5 & 6: Deploying Llama 4 on G4 (8x RTX Pro 6000)"
echo "--------------------------------------------------------"

# [START hypercomputer_gpu_infer_llama4scout_g4_gpu_path_configuration]
RELEASE_NAME="${USER}-serving-llama-4-g4"
CHART_PATH="${REPO_ROOT}/src/helm-charts/a4/inference-templates/deployment"
VALUES_FILE="${REPO_ROOT}/inference/a4/single-host-serving/vllm/values.yaml"
TARGET_MODEL="${MODEL_ID}"
# [END hypercomputer_gpu_infer_llama4scout_g4_gpu_path_configuration]

echo "Installing Helm chart release: ${RELEASE_NAME}"
echo "Model: ${TARGET_MODEL}"

# 7. Install Helm release
# [START hypercomputer_gpu_infer_llama4scout_g4_helm_installation]
helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
    -f "${VALUES_FILE}" \
    --set volumes.gcsMounts[0].bucketName="${GCS_BUCKET}" \
    --set volumes.gcsMounts[0].mountPath="/gcs" \
    --set volumes.ssdMountPath="/tmp" \
    --set workload.model.name="${TARGET_MODEL}" \
    --set workload.image="${FULL_IMAGE_NAME}" \
    --set workload.gpus=8 \
    --set workload.replicas=0 \
    --set workload.configFile="" \
    --set workload.configPath="" \
    --set service.type=ClusterIP \
    --set service.ports.http=8000 \
    --set network.gibVersion="" \
    --set workload.tolerations[0].key="cloud.google.com/gke-accelerator" \
    --set workload.tolerations[0].operator="Exists" \
    --set workload.tolerations[0].effect="NoSchedule" \
    --set workload.tolerations[1].key="nvidia.com/gpu" \
    --set workload.tolerations[1].operator="Exists" \
    --set workload.tolerations[1].effect="NoSchedule"
# [END hypercomputer_gpu_infer_llama4scout_g4_helm_installation]

# 8. Apply customized G4 workload launcher ConfigMap
echo "Applying RTX Pro 6000 launcher ConfigMap..."
# [START hypercomputer_gpu_infer_llama4scout_g4_launcher_configmap]
SCRIPT_CONTENT='#!/bin/bash
if [[ -n "${NCCL_INIT_SCRIPT}" ]]; then
  echo "Running NCCL init script: ${NCCL_INIT_SCRIPT}"
  source ${NCCL_INIT_SCRIPT}
fi

export TORCH_CUDA_ARCH_LIST="10.0"
export VLLM_DISABLE_CUSTOM_ALL_REDUCE=0
export VLLM_USE_V1=0
export NCCL_DEBUG=WARN
export HF_HOME="/tmp/hf_home"

MODEL="'"${TARGET_MODEL}"'"

echo "Starting vLLM OpenAI API Server via python3 for model: ${MODEL} on 8x RTX Pro 6000..."
exec python3 -m vllm.entrypoints.openai.api_server \
  --model "${MODEL}" \
  --tensor-parallel-size 8 \
  --pipeline-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --enforce-eager \
  --trust-remote-code
'
# [END hypercomputer_gpu_infer_llama4scout_g4_launcher_configmap]

# [START hypercomputer_gpu_infer_llama4scout_g4_create_configmap]
kubectl create configmap "${RELEASE_NAME}-launcher" \
    --from-literal=launch-workload.sh="${SCRIPT_CONTENT}" \
    --dry-run=client -o yaml | \
kubectl label --local -f - "app.kubernetes.io/managed-by=Helm" -o yaml | \
kubectl annotate --local -f - "meta.helm.sh/release-name=${RELEASE_NAME}" "meta.helm.sh/release-namespace=default" -o yaml | \
kubectl apply -f -
# [END hypercomputer_gpu_infer_llama4scout_g4_create_configmap]

# 9. Apply tolerations patch
# [START hypercomputer_gpu_infer_llama4scout_g4_apply_patch]
echo "Applying toleration patch for RTX Pro 6000 GPUs..."
sleep 2

kubectl patch deployment "${RELEASE_NAME}" --type=strategic -p '{
  "spec": {
    "replicas": 1,
    "template": {
      "spec": {
        "tolerations": [
          {
            "key": "cloud.google.com/gke-accelerator",
            "operator": "Exists",
            "effect": "NoSchedule"
          },
          {
            "key": "nvidia.com/gpu",
            "operator": "Exists",
            "effect": "NoSchedule"
          }
        ]
      }
    }
  }
}'
# [END hypercomputer_gpu_infer_llama4scout_g4_apply_patch]

echo "--------------------------------------------------------"
echo "Deployment submitted! Check pods using:"
echo "  kubectl get pods -w"
echo "--------------------------------------------------------"
