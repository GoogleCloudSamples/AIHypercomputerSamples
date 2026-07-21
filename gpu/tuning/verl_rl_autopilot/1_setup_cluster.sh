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

set -euo pipefail

source 0_env.sh

# Create an Autopilot cluster on Rapid channel (required for DRANET in some versions)
# We also enable-ray-operator as in the original script.
echo "Creating Autopilot cluster ${CLUSTER_NAME}..."
# [START hypercomputer_gpu_train_ray_verl_auto_create_cluster]
gcloud container clusters create-auto ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --release-channel=rapid \
    --enable-ray-operator
# [END hypercomputer_gpu_train_ray_verl_auto_create_cluster]

# Get credentials for your cluster:
# [START hypercomputer_gpu_train_ray_verl_auto_get_creds]
gcloud container clusters get-credentials ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION}
# [END hypercomputer_gpu_train_ray_verl_auto_get_creds]

echo "Autopilot cluster ${CLUSTER_NAME} created and credentials configured."

