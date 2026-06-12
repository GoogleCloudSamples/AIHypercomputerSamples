#!/bin/bash
source 0_env.sh

set -e
set -x

# 1. Build and Submit
# [START hypercomputer_gpu_tune_gemma3_gke_build_submit]
gcloud builds submit . --substitutions=_ARTIFACT_REPO_LOCATION="${ARTIFACT_REPO_LOCATION}"
# [END hypercomputer_gpu_tune_gemma3_gke_build_submit]

# 2. Set image name for the job template
# [START hypercomputer_gpu_tune_gemma3_gke_set_image_url]
export IMAGE_URL="${ARTIFACT_REPO_LOCATION}-docker.pkg.dev/${PROJECT_ID}/gemma/finetune-gemma-gpu:1.0.0"
# [END hypercomputer_gpu_tune_gemma3_gke_set_image_url]

# 3. Deploy Job
# [START hypercomputer_gpu_tune_gemma3_gke_deploy_job]
envsubst < finetune.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_deploy_job]
