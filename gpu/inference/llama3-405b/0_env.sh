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

# [START hypercomputer_gpu_infer_llama3_405b_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export GCS_BUCKET="YOUR_BUCKET_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export CLUSTER_TOOLKIT_VERSION="v1.104.0"
export DYNAMO_RELEASE_VERSION="1.5.0"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_gpu_infer_llama3_405b_env]

# Ensure CLUSTER_NAME is <= 20 chars so service account IDs (${CLUSTER_NAME}-gke-np-sa) stay <= 30 chars
if [[ "${CLUSTER_NAME}" == pkb-*-cluster ]]; then
  export CLUSTER_NAME="${CLUSTER_NAME%-cluster}"
elif [[ ${#CLUSTER_NAME} -gt 20 && "${CLUSTER_NAME}" != "YOUR_CLUSTER_NAME" ]]; then
  export CLUSTER_NAME="${CLUSTER_NAME:0:20}"
fi
