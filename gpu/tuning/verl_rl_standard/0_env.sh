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
export GPU_TYPE="YOUR_GPU_TYPE"
export CONTROL_PLANE_REGION="YOUR_CONTROL_PLANE_REGION"
export NODE_ZONE="YOUR_NODE_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export KSA_NAME="YOUR_KSA_NAME"
export GS_BUCKET="YOUR_BUCKET_NAME"
export HF_TOKEN="HUGGING_FACE_TOKEN"
export RESERVATION="YOUR_RESERVATION"
export MACHINE_TYPE="a4-highgpu-8g"
export NAMESPACE="default"

export GVNIC_NETWORK_PREFIX="standard-gvnic"
export RDMA_NETWORK_PREFIX="standard-rdma"
# [END hypercomputer_gpu_train_ray_verl_std_env]

