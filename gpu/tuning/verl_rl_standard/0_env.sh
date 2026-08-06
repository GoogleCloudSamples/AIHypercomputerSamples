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

# [START hypercomputer_gpu_train_ray_verl_std_env]
export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export CONTROL_PLANE_REGION="YOUR_REGION"
export NODE_ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export KSA_NAME="YOUR_KSA_NAME"
export GS_BUCKET="YOUR_GCS_BUCKET"
export NAMESPACE="default"
export GPU_TYPE="nvidia-b200"
export MACHINE_TYPE="a4-highgpu-8g"
export RESERVATION="YOUR_RESERVATION_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"

export GVNIC_NETWORK_PREFIX="gvnic-name"
export RDMA_NETWORK_PREFIX="rdma-name"
# [END hypercomputer_gpu_train_ray_verl_std_env]
