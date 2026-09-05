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

echo "==================== Running Smoke Test Validation ===================="

# Helper function to check GCS path
check_gcs_path() {
  local path="$1"
  echo "Checking GCS path: $path"
  if gcloud storage ls "$path" &>/dev/null; then
    echo "  [OK] Path exists and is not empty."
    return 0
  else
    echo "  [ERROR] Path does not exist or is empty."
    return 1
  fi
}

FAILED=0

# 1. Check GCS Bucket
if ! gcloud storage buckets describe "gs://${GCS_BUCKET}" &>/dev/null; then
  echo "  [ERROR] GCS Bucket gs://${GCS_BUCKET} does not exist."
  FAILED=1
else
  echo "  [OK] GCS Bucket gs://${GCS_BUCKET} exists."
  
  # 2. Check Converted MaxText Model
  check_gcs_path "gs://${GCS_BUCKET}/qwen-3-14b/max-text-format/" || FAILED=1

  # 3. Check Trained Model (we expect at least some checkpoints)
  check_gcs_path "gs://${GCS_BUCKET}/qwen-3-14b/trained/" || FAILED=1

  # 4. Check Converted HF Model
  check_gcs_path "gs://${GCS_BUCKET}/qwen-3-14b/hf-trained/" || FAILED=1
fi

# 5. Check Docker Image in Artifact Registry
echo "Checking Docker image: ${CLOUD_IMAGE_NAME}"
if ! gcloud container images describe "${CLOUD_IMAGE_NAME}" --project="${PROJECT}" &>/dev/null; then
  echo "  [ERROR] Docker image ${CLOUD_IMAGE_NAME} does not exist."
  FAILED=1
else
  echo "  [OK] Docker image exists."
fi

# 6. Check GKE Cluster
echo "Checking GKE Cluster: ${CLUSTER_NAME}"
if ! gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" &>/dev/null; then
  echo "  [ERROR] GKE Cluster ${CLUSTER_NAME} does not exist or is not accessible."
  FAILED=1
else
  echo "  [OK] GKE Cluster exists and is accessible."
fi

if [ $FAILED -ne 0 ]; then
  echo "==================== Smoke Test FAILED ===================="
  exit 1
else
  echo "==================== Smoke Test PASSED ===================="
  exit 0
fi
