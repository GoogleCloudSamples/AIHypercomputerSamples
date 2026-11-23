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

# [START hypercomputer_gpu_tune_gemma4_multihost_gke_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="YOUR_CLUSTER_NAME" # maximum 40 chars; start with a-z; only a-z, 0-9, -
export CLUSTER_REGION="YOUR_REGION" # for example, us-central1
export RESERVATION="YOUR_RESERVATION_NAME"
export HF_TOKEN="YOUR_HF_TOKEN"
export ARTIFACT_REPO_LOCATION="YOUR_ARTIFACT_REGISTRY_LOCATION" # for example, us-central1
export NUM_NODES="YOUR_NUMBER_OF_NODES" # Number of A4 nodes (for example, 2)

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_env]
