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

export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
export CLUSTER_REGION="YOUR_CLUSTER_REGION"
export RESERVATION="YOUR_RESERVATION"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export NODE_POOL_NAME="llama4-scout-b200-node-pool"
export GCS_BUCKET="YOUR_BUCKET_NAME"
export ARTIFACT_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/vllm4-repo"
export VLLM_IMAGE="vllm-openai"
export BASE_TAG="latest"
export MODEL_ID="meta-llama/Llama-4-Scout-17B-16E-Instruct"
export VLLM_VERSION="cu128-nightly"
export HF_TOKEN="YOUR_HF_TOKEN"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
