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

# [START hypercomputer_gpu_train_qwen_megatron_gke_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION" # for example, us-central1
export ZONE="YOUR_ZONE" # for example, us-central1-b
export CLUSTER_NAME="YOUR_CLUSTER_NAME" # maximum 20 chars; start with a-z; only a-z, 0-9, -
export BUCKET_NAME="YOUR_GCS_BUCKET" # globally unique Cloud Storage bucket for Terraform state
export RESERVATION_NAME="YOUR_RESERVATION_NAME" # reservation name or RESERVATION_NAME/reservationBlocks/RESERVATION_BLOCK_NAME
export CLUSTER_TOOLKIT_VERSION="v1.109.0"
export NODE_COUNT=2
export AUTHORIZED_CIDR="0.0.0.0/0" # or restrict to your workstation IP as a /32

gcloud config set project "${PROJECT_ID:?}"
gcloud config set billing/quota_project "${PROJECT_ID:?}"
# [END hypercomputer_gpu_train_qwen_megatron_gke_env]

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
