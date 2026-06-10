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

# [START hypercomputer_gpu_tune_gemma3_gke_env]
export PROJECT_ID="<PROJECT_ID>"
export USER_EMAIL="<USER_EMAIL>" 
export CLUSTER_NAME="gemma3-finetune-cluster"
export REGION="us-central1"
export RESERVATION="<RESERVATION_ID>"
export HF_TOKEN="<HF_TOKEN>"
export IMAGE_URL="us-docker.pkg.dev/${PROJECT_ID}/gemma/finetune-gemma-gpu:1.0.0"
# [END hypercomputer_gpu_tune_gemma3_gke_env]
