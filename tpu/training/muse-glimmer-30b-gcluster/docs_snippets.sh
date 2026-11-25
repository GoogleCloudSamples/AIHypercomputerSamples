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

# [START hypercomputer_tpu_train_muse_glimmer_30b_authenticate]
gcloud auth login
gcloud auth application-default login
# [END hypercomputer_tpu_train_muse_glimmer_30b_authenticate]

# [START hypercomputer_tpu_train_muse_glimmer_30b_install_cluster_toolkit]
curl -L -O "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/v${CTK_VERSION}/gcluster_bundle_linux_amd64.tgz"
mkdir -p ~/cluster-toolkit && tar -xzf gcluster_bundle_linux_amd64.tgz -C ~/cluster-toolkit
cd ~/cluster-toolkit && ./gcluster --version
# [END hypercomputer_tpu_train_muse_glimmer_30b_install_cluster_toolkit]

# [START hypercomputer_tpu_train_muse_glimmer_30b_clone_torchtitan_home]
cd ~
git clone https://github.com/google-pytorch/torchtitan.git
cd torchtitan && git checkout torch-tpu-v0.2.0
# [END hypercomputer_tpu_train_muse_glimmer_30b_clone_torchtitan_home]

# [START hypercomputer_tpu_train_muse_glimmer_30b_cd_cluster_toolkit]
cd ~/cluster-toolkit
# [END hypercomputer_tpu_train_muse_glimmer_30b_cd_cluster_toolkit]

# Optional smoke test
# [START hypercomputer_tpu_train_muse_glimmer_30b_set_smoke_config]
cd ~/cluster-toolkit
export CONFIG=muse_glimmer_debugmodel
export EXTRA=""
export WORKLOAD_NAME="${CLUSTER_NAME}-smoke"
# [END hypercomputer_tpu_train_muse_glimmer_30b_set_smoke_config]

# [START hypercomputer_tpu_train_muse_glimmer_30b_delete_resources]
gcloud storage rm -r "gs://${BUCKET_NAME}" "gs://${TF_STATE_BUCKET}"
gcloud artifacts repositories delete "$AR_REPO" --location "$REGION" --quiet
# [END hypercomputer_tpu_train_muse_glimmer_30b_delete_resources]
