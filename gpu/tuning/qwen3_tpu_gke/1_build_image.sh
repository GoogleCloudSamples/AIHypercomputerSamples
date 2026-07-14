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

echo "[$(date)] ==================== Creating Cloud Storage bucket... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_create_bucket]
gcloud storage buckets create gs://$GCS_BUCKET --project=$PROJECT --location=$REGION || true
# [END hypercomputer_tpu_tune_qwen3_sft_create_bucket]
echo "[$(date)] ==================== Cloud Storage bucket created. ===================="

echo "[$(date)] ==================== Creating Artifact Registry repository... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_create_repo]
gcloud artifacts repositories create maxtext-images \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT \
    --description="Docker repository for MaxText images in $REGION" || true
# [END hypercomputer_tpu_tune_qwen3_sft_create_repo]
echo "[$(date)] ==================== Artifact Registry repository created. ===================="

echo "[$(date)] ==================== Creating build VM... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_create_vm]
gcloud compute instances create $VM_NAME \
  --zone $ZONE \
  --project $PROJECT \
  --machine-type n4-standard-16 \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name=$VM_NAME,image-family=ubuntu-2404-lts-amd64,image-project=ubuntu-os-cloud,mode=rw,size=200,type=hyperdisk-balanced
# [END hypercomputer_tpu_tune_qwen3_sft_create_vm]
echo "[$(date)] ==================== Build VM created. ===================="

echo "[$(date)] ==================== Waiting for VM to be ready... ===================="
# Wait until SSH is available on the VM
while ! gcloud compute ssh $VM_NAME --project $PROJECT --zone $ZONE --command="echo SSH ready" 2>/dev/null; do
  echo "Waiting for SSH to become available..."
  sleep 5
done
echo "[$(date)] ==================== VM is ready. ===================="

echo "[$(date)] ==================== Building and pushing Docker image on VM... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_build_image_auto]
gcloud compute ssh $VM_NAME --project $PROJECT --zone $ZONE --command="
set -euo pipefail

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo groupadd docker || true
sudo usermod -aG docker \$USER

# Install uv and MaxText
curl -LsSf https://astral.sh/uv/install.sh | sh
source \$HOME/.local/bin/env
uv venv --python 3.12 --seed maxtext_venv
source maxtext_venv/bin/activate
uv pip install maxtext[runner]==0.2.1 --resolution=lowest

# Build the Docker image (using the full path to the venv executable since sg starts a new subshell)
sg docker -c "\$HOME/maxtext_venv/bin/build_maxtext_docker_image WORKFLOW=post-training"

# Push the Docker image
# We use the VM's default service account (with cloud-platform scope) to push
gcloud auth configure-docker --quiet ${REGION}-docker.pkg.dev
sg docker -c 'docker tag maxtext_base_image ${CLOUD_IMAGE_NAME}'
sg docker -c 'docker push ${CLOUD_IMAGE_NAME}'
"
# [END hypercomputer_tpu_tune_qwen3_sft_build_image_auto]
echo "[$(date)] ==================== Docker image built and pushed. ===================="
