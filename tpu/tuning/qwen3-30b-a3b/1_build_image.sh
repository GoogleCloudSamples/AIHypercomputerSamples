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

echo "[$(date)] ==================== Build started. ===================="

echo "[$(date)] ==================== Creating Cloud Storage bucket... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_bucket]
gcloud storage buckets create gs://$GCS_BUCKET --project=$PROJECT --location=$REGION || true
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_bucket]
echo "[$(date)] ==================== Cloud Storage bucket created. ===================="

echo "[$(date)] ==================== Creating Artifact Registry repository... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_repo]
gcloud artifacts repositories create maxtext-images \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT \
    --description="Docker repository for MaxText images in $REGION" || true
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_repo]
echo "[$(date)] ==================== Artifact Registry repository created. ===================="

echo "[$(date)] ==================== Submitting Cloud Build job... ===================="

cat << 'EOF' > Dockerfile
FROM python:3.12-slim-bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    git \
    build-essential \
    ca-certificates && \
    mkdir -p /usr/share/keyrings && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y --no-install-recommends google-cloud-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN git clone https://github.com/google/maxtext.git /workspace/maxtext
WORKDIR /workspace/maxtext
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir absl-py transformers torch sentencepiece tiktoken accelerate ml_dtypes safetensors orbax-checkpoint flax optax jax jaxlib
RUN pip install --no-cache-dir ".[all]" || pip install --no-cache-dir .

ENV PYTHONPATH=/workspace/maxtext
EOF

# [START hypercomputer_tpu_tune_qwen3_30b_rl_build_image_cb]
gcloud builds submit . \
    --project=$PROJECT \
    --region=$REGION \
    --tag="${CLOUD_IMAGE_NAME}"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_build_image_cb]
echo "[$(date)] ==================== Cloud Build job completed. ===================="

echo "[$(date)] ==================== Build finished. ===================="
