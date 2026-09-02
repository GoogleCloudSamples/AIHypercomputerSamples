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

echo "[$(date)] ==================== Build stage started ===================="

echo "[$(date)] ==================== Creating Cloud Storage bucket... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_bucket]
gcloud storage buckets create "gs://${GCS_BUCKET}" --project="${PROJECT}" --location="${REGION}" 2>/dev/null || true
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_bucket]
echo "[$(date)] ==================== Cloud Storage bucket ready. ===================="

echo "[$(date)] Using pre-built official MaxText image: ${CLOUD_IMAGE_NAME}"

echo "[$(date)] ==================== Build stage finished. ===================="