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

# This file contains the exact documentation snippets for checking logs,
# containing placeholders like <pod suffix> that shouldn't be executed in CI.

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_cb_env]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export CLOUD_IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT/maxtext-images/maxtext_base:latest"
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_cb_env]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_cb_kubectl_install]
# Download the latest stable kubectl release (or specify your cluster version)
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
wget https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
chmod +x kubectl
sudo cp kubectl /usr/bin/
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_cb_kubectl_install]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_model_logs]
# Check progress at
kubectl logs hf-to-mt-main-job-0-0-<pod suffix> -f
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_model_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_train_logs]
# Check progress at
kubectl logs sft-main-job-0-0-<pod suffix> -f
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_train_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_hf_logs]
# Check progress at
kubectl logs mt-to-hf-main-job-0-0-<pod suffix> -f

# The trained model is now available in gs://$GCS_BUCKET/qwen-3-14b/hf-trained/ - though again, it's ~2x the size of the original...
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_convert_hf_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_gcluster_cleanup_storage]
gcluster destroy ${CLUSTER_NAME} --auto-approve --robust
gcloud storage rm -r gs://$GCS_BUCKET
gcloud artifacts repositories delete ${REPOSITORY_NAME} --location=$REGION --project=$PROJECT --quiet
rm -rf cloudbuild.yaml gke-tpu-v6e-advanced.yaml kueue-configuration.yaml.tftpl .ghpc ${CLUSTER_NAME}
# [END hypercomputer_tpu_tune_qwen3_sft_gcluster_cleanup_storage]
