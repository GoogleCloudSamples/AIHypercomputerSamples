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

source 0_env.sh

set -euo pipefail

# 1. Build and Submit
# [START hypercomputer_gpu_tune_gemma3_gke_build_submit]
gcloud builds submit . --substitutions=_ARTIFACT_REPO_LOCATION="${ARTIFACT_REPO_LOCATION}"
# [END hypercomputer_gpu_tune_gemma3_gke_build_submit]
echo "[$(date)] ==================== Build finished. ===================="

# 2. Set image name for the job template
# [START hypercomputer_gpu_tune_gemma3_gke_set_image_url]
export IMAGE_URL="${ARTIFACT_REPO_LOCATION}-docker.pkg.dev/${PROJECT_ID}/gemma/finetune-gemma-gpu:1.0.0"
# [END hypercomputer_gpu_tune_gemma3_gke_set_image_url]

# 3. Deploy Job
# [START hypercomputer_gpu_tune_gemma3_gke_deploy_job]
envsubst < finetune.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_deploy_job]
echo "[$(date)] ==================== Job deployed. ===================="

