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

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_env]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export ZONE="YOUR_ZONE"
# Cluster name is currently hardcoded (need to modify deployment file)
export CLUSTER_NAME=gke-tpu-v6e
export REPOSITORY_NAME="YOUR_REPOSITORY_NAME"
export CLOUD_IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT/${REPOSITORY_NAME}/maxtext_base:latest"
export TPU_TYPE="v6e-32"
export RESERVATION="YOUR_RESERVATION_NAME"
export MODEL_NAME="qwen3-14b"
export HF_TOKEN="YOUR_HF_TOKEN"
export GCS_BUCKET="YOUR_UNIQUE_BUCKET_NAME"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_env]

echo "[$(date)] ==================== Installing Prerequisites ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_install_terraform]
wget https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip
unzip terraform_1.12.2_linux_amd64.zip 
sudo cp terraform /usr/bin/

wget https://releases.hashicorp.com/packer/1.15.3/packer_1.15.3_linux_amd64.zip
unzip packer_1.15.3_linux_amd64.zip
sudo cp packer /usr/bin/
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_install_terraform]
echo "[$(date)] ==================== Prerequisites Installed ===================="
