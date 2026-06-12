#!/bin/bash
source 0_env.sh

set -e
set -x

# 1. Build and Submit
# [START hypercomputer_gpu_tune_gemma3_gke_build_submit]
gcloud builds submit .
# [END hypercomputer_gpu_tune_gemma3_gke_build_submit]

# 2. Deploy Job
# [START hypercomputer_gpu_tune_gemma3_gke_deploy_job]
envsubst < finetune.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_gke_deploy_job]
