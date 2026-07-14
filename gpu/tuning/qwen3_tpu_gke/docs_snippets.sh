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

# [START hypercomputer_tpu_tune_qwen3_sft_monitor_pods]
kubectl get pod
# [END hypercomputer_tpu_tune_qwen3_sft_monitor_pods]

# [START hypercomputer_tpu_tune_qwen3_sft_monitor_logs]
kubectl logs -f POD_NAME
# [END hypercomputer_tpu_tune_qwen3_sft_monitor_logs]

# [START hypercomputer_tpu_tune_qwen3_sft_monitor_workload]
xpk workload list --cluster ${CLUSTER_NAME} --project ${PROJECT} --zone ${ZONE}
# [END hypercomputer_tpu_tune_qwen3_sft_monitor_workload]

# [START hypercomputer_tpu_tune_qwen3_sft_monitor_train_logs]
kubectl logs -f qwen-training-pathways-head-0-0-HASH
# [END hypercomputer_tpu_tune_qwen3_sft_monitor_train_logs]


# ==============================================================================
# The following snippets represent manual steps from the tutorial for building
# the image. In the automated pipeline, these are combined into a single SSH command.
# ==============================================================================

# [START hypercomputer_tpu_tune_qwen3_sft_ssh_vm]
gcloud compute ssh $VM_NAME --project $PROJECT --zone $ZONE
# [END hypercomputer_tpu_tune_qwen3_sft_ssh_vm]

# [START hypercomputer_tpu_tune_qwen3_sft_install_docker]
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo groupadd docker
sudo usermod -aG docker $USER
# [END hypercomputer_tpu_tune_qwen3_sft_install_docker]

# [START hypercomputer_tpu_tune_qwen3_sft_install_uv]
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

uv venv --python 3.12 --seed maxtext_venv
source maxtext_venv/bin/activate
uv pip install maxtext[runner]==0.2.1 --resolution=lowest
# [END hypercomputer_tpu_tune_qwen3_sft_install_uv]

# [START hypercomputer_tpu_tune_qwen3_sft_build_docker]
build_maxtext_docker_image WORKFLOW=post-training
# [END hypercomputer_tpu_tune_qwen3_sft_build_docker]

# [START hypercomputer_tpu_tune_qwen3_sft_push_docker]
gcloud auth login --quiet

export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export CLOUD_IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT/maxtext-images/maxtext_base:latest"

docker tag maxtext_base_image $CLOUD_IMAGE_NAME

gcloud auth configure-docker --quiet $REGION-docker.pkg.dev
docker push $CLOUD_IMAGE_NAME
# [END hypercomputer_tpu_tune_qwen3_sft_push_docker]
