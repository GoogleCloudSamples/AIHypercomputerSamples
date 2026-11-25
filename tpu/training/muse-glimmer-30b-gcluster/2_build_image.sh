#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

echo "[$(date)] ==================== Creating Artifact Registry repository... ===================="
if gcloud artifacts repositories describe "$AR_REPO" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Artifact Registry repository ${AR_REPO} already exists. Skipping creation."
else
  # [START hypercomputer_tpu_train_muse_glimmer_30b_create_repository]
  gcloud artifacts repositories create "$AR_REPO" --repository-format=docker --location="$REGION" --project="$PROJECT_ID"
  # [END hypercomputer_tpu_train_muse_glimmer_30b_create_repository]
fi

echo "[$(date)] ==================== Cloning TorchTitan... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_clone_torchtitan]
git clone https://github.com/google-pytorch/torchtitan.git
cd torchtitan && git checkout torch-tpu-v0.2.0
# [END hypercomputer_tpu_train_muse_glimmer_30b_clone_torchtitan]

echo "[$(date)] ==================== Writing Cloud Build configuration... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_cloudbuild_config]
cat > cloudbuild.yaml <<'EOF'
steps:
  - name: gcr.io/cloud-builders/docker
    args: [build, -t, '${_IMAGE}', -f, torchtitan/experiments/tpu/Dockerfile,
           --build-arg, TORCH_TPU_VERSION=0.2.0,
           --build-arg, TORCH_VERSION=2.15.0,
           --build-arg, TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu, .]
images: ['${_IMAGE}']
options: {machineType: E2_HIGHCPU_8, diskSizeGb: 200, logging: CLOUD_LOGGING_ONLY}
timeout: 3600s
EOF
# [END hypercomputer_tpu_train_muse_glimmer_30b_cloudbuild_config]

echo "[$(date)] ==================== Building and pushing ${WORKLOAD_IMAGE}... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_build_image]
gcloud builds submit --project "$PROJECT_ID" --region "$REGION" \
  --config cloudbuild.yaml --substitutions=_IMAGE="$WORKLOAD_IMAGE" .
# [END hypercomputer_tpu_train_muse_glimmer_30b_build_image]

echo "[$(date)] ==================== Image build completed. ===================="
