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

# [START hypercomputer_gpu_train_ray_verl_auto_env]
export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export CONTROL_PLANE_REGION="YOUR_REGION"
export NODE_ZONE="YOUR_ZONE"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export KSA_NAME="YOUR_KSA_NAME"
export GS_BUCKET="YOUR_GCS_BUCKET"
export NAMESPACE="default"
export GPU_TYPE="YOUR_GPU_TYPE"
export MACHINE_TYPE="YOUR_MACHINE_TYPE"
export RESERVATION="YOUR_RESERVATION_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
# [END hypercomputer_gpu_train_ray_verl_auto_env]

# Timeout for waiting for Ray GPU worker pods to become Ready.
# Used in 5_deploy_workload.sh.
# Default value is 1320s (22 minutes) to account for potential
# GPU node provisioning delays.
# Can be parameterized by setting --tpu_sample_var=WORKER_TIMEOUT=1200s
# for example.
export WORKER_TIMEOUT="YOUR_WORKER_TIMEOUT"