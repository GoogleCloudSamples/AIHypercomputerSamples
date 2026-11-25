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

# [START hypercomputer_tpu_train_muse_glimmer_30b_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export RESERVATION_NAME="YOUR_RESERVATION_NAME"
export TF_STATE_BUCKET="YOUR_STATE_BUCKET_NAME"
export BUCKET_NAME="YOUR_OUTPUT_BUCKET_NAME"
export AR_REPO="YOUR_REPOSITORY_NAME"
export TOPOLOGY="8x8"
export NNODES=16
export NPROC_PER_NODE=4
export BASE_OUTPUT_DIR="gs://${BUCKET_NAME}"
export WORKLOAD_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/torchtitan-runner:torch-tpu-v0.2.0"
export CTK_VERSION="1.106.0"

gcloud config set project "${PROJECT_ID}"
gcloud auth application-default set-quota-project "${PROJECT_ID}"
# [END hypercomputer_tpu_train_muse_glimmer_30b_env]

# Ensure CLUSTER_NAME is <= 20 chars so that the service account IDs that
# Cluster Toolkit derives from it (${CLUSTER_NAME}-gke-np-sa) stay <= 30 chars.
case "${CLUSTER_NAME}" in
  pkb-*-cluster)
    export CLUSTER_NAME="${CLUSTER_NAME%-cluster}"
    ;;
esac
if [ "${#CLUSTER_NAME}" -gt 20 ]; then
  CLUSTER_NAME="$(printf '%.20s' "${CLUSTER_NAME}")"
  export CLUSTER_NAME
fi
