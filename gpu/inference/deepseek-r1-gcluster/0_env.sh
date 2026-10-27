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

# [START hypercomputer_gpu_infer_deepseek_r1_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export MODEL_BUCKET="YOUR_GCS_BUCKET"
export TERRAFORM_BUCKET="${MODEL_BUCKET}-tf-state"
export CLUSTER_TOOLKIT_VERSION="v1.104.0"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_gpu_infer_deepseek_r1_env]

# Keep CLUSTER_NAME <= 20 characters so that the service account IDs created by
# Cluster Toolkit (${CLUSTER_NAME}-gke-np-sa) stay within the 30-character limit.
case "${CLUSTER_NAME}" in
  pkb-*-cluster)
    export CLUSTER_NAME="${CLUSTER_NAME%-cluster}"
    ;;
esac
if [ "${#CLUSTER_NAME}" -gt 20 ]; then
  CLUSTER_NAME="$(printf '%.20s' "${CLUSTER_NAME}")"
  export CLUSTER_NAME
fi
