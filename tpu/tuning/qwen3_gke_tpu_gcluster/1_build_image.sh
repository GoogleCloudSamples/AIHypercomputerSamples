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
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_create_bucket]
gcloud storage buckets create gs://$GCS_BUCKET --project=$PROJECT --location=$REGION || true
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_create_bucket]
echo "[$(date)] ==================== Cloud Storage bucket created. ===================="

echo "[$(date)] ==================== Creating Artifact Registry repository... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_create_repo]
gcloud artifacts repositories create ${REPOSITORY_NAME} \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT \
    --description="Docker repository for MaxText images in $REGION" || true
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_create_repo]
echo "[$(date)] ==================== Artifact Registry repository created. ===================="

echo "[$(date)] ==================== Submitting Cloud Build job... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_build_image_cb]
gcloud builds submit . \
    --project=$PROJECT \
    --region=$REGION \
    --substitutions=_CLOUD_IMAGE_NAME="${CLOUD_IMAGE_NAME}"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_build_image_cb]
echo "[$(date)] ==================== Cloud Build job completed. ===================="

echo "[$(date)] ==================== Build finished. ===================="
