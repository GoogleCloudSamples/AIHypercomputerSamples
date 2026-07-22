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

echo "[$(date)] ==================== Creating Cluster... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
# Start with creating a new virtual environment to install XPK in.
VENV_DIR=venvp3
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate
pip install xpk==1.14.0

xpk cluster create-pathways \
  --num-slices=${CLUSTER_NODEPOOL_COUNT} \
  --tpu-type=${TPU_TYPE} \
  --pathways-gce-machine-type=${PW_CPU_MACHINE_TYPE} \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --cluster=${CLUSTER_NAME} \
  --custom-cluster-arguments="--enable-ip-alias" \
  --custom-nodepool-arguments="--disk-size=500" \
  --reservation=$RESERVATION \
  --default-pool-cpu-machine-type=n4-standard-16

gcloud container clusters get-credentials $CLUSTER_NAME \
  --location=$REGION \
  --project $PROJECT
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
echo "[$(date)] ==================== Cluster created. ===================="
