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

# [START hypercomputer_tpu_train_qwen3-30b_rl_env]
#
# ==============================================================================
# 1. GLOBAL GOOGLE CLOUD CONFIGURATION
# ==============================================================================
export PROJECT="PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"

# ==============================================================================
# 2. STORAGE & REPOSITORY CONFIGURATION
# ==============================================================================
# Cloud Storage bucket for model checkpoints and training outputs
export GCS_BUCKET="BUCKET_NAME"

# Target Docker image path in Artifact Registry
export CLOUD_IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT}/maxtext-images/maxtext_base:latest"

# ==============================================================================
# 3. TEMPORARY BUILD VM CONFIGURATION (Used only in setup.sh)
# ==============================================================================
# Resources for the temporary VM that builds the MaxText Docker image
export VM_NAME="builder-vm"
export BUILDER_MACHINE_TYPE="n4-standard-16"
export BUILD_IMAGE_FAMILY="ubuntu-2404-lts-amd64"
export BUILD_IMAGE_PROJECT="ubuntu-os-cloud"
export BUILD_DISK_SIZE="200"
export BUILD_DISK_TYPE="hyperdisk-balanced"

# ==============================================================================
# 4. GKE PATHWAYS CLUSTER CONFIGURATION (Used in 1_deploy_cluster.sh)
# ==============================================================================
# GKE Cluster name and capacity reservation details
export CLUSTER_NAME="CLUSTER_NAME"
export RESERVATION=""

# TPU topology definition
export TPU_TYPE="v6e-64"
export CLUSTER_NODEPOOL_COUNT=1

# Powerful CPU instances acting as Pathways management nodes in the cluster
export PW_CPU_MACHINE_TYPE="c4d-standard-96"

# ==============================================================================
# 5. MACHINE LEARNING MODEL & AUTHENTICATION
# ==============================================================================
# Model metadata and Hugging Face access token for weights download
export MODEL_NAME="qwen3-30b-a3b"
export HF_TOKEN="HUGGING_FACE_TOKEN"

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_tpu_train_qwen3-30b_rl_env]
