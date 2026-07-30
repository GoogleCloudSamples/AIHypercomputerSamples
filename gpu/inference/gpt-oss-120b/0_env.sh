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

set -euo pipefail

# Set your environment variables here.
# DO NOT PUT ANY SECRET VALUES HERE!

# [START hypercomputer_gpu_infer_gptoss120b_env]
export PROJECT_ID="YOUR_PROJECT_ID"
export RESERVATION_URL="YOUR_RESERVATION_NAME"
export REGION="YOUR_REGION"
export CLUSTER_NAME="YOUR_CLUSTER_NAME"
export GCS_BUCKET="YOUR_GCS_BUCKET"
export HUGGING_FACE_TOKEN="YOUR_HF_TOKEN"
export NETWORK="YOUR_NETWORK_NAME"
export SUBNETWORK="YOUR_SUBNETWORK_NAME"
export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")

gcloud config set project "${PROJECT_ID}"
gcloud config set billing/quota_project "${PROJECT_ID}"
# [END hypercomputer_gpu_infer_gptoss120b_env]