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

# [START hypercomputer_tpu_tune_qwen3_30b_rl_copy_blueprint]
cp examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml .
# [END hypercomputer_tpu_tune_qwen3_30b_rl_copy_blueprint]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
./gcluster deploy gke-tpu-v6e-advanced.yaml \
    --vars project_id="${PROJECT}" \
    --vars deployment_name="${CLUSTER_NAME}" \
    --vars region="${REGION}" \
    --vars zone="${ZONE}" \
    --vars num_slices="${CLUSTER_NODEPOOL_COUNT}" \
    --vars tpu_topology="${TOPOLOGY}" \
    --vars authorized_cidr="0.0.0.0/0" \
    --vars reservation="${RESERVATION:-}" \
    -l IGNORE --auto-approve -w
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_configure_defaults]
# Configure gcluster Defaults
./gcluster job config set project "${PROJECT}"
./gcluster job config set cluster "${CLUSTER_NAME}"
./gcluster job config set location "${REGION}"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_configure_defaults]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_convert_model_logs]
# Use the list command to check status
./gcluster job list

# Check progress of the job (--main-only targets the coordinator pod (Job Index 0, Pod Index 0) to avoid duplicate logs from other workers)
./gcluster job logs qwen-hf-to-mt --main-only -f
# [END hypercomputer_tpu_tune_qwen3_30b_rl_convert_model_logs]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_verify_converted_model]
gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_verify_converted_model]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_train_logs_v2]
# Use the list command to check status
./gcluster job list

# Ensure kubectl credentials are configured
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT}"

# Check progress of the job
kubectl logs -f \
    -l jobset.sigs.k8s.io/replicatedjob-name=pathways-head \
    -c workload-container
# [END hypercomputer_tpu_tune_qwen3_30b_rl_train_logs_v2]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_verify_training_checkpoints]
gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/trained/rl/checkpoints/actor/"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_verify_training_checkpoints]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_convert_hf_logs]
# Use the list command to check status
./gcluster job list

# Check progress of the job (--main-only targets the coordinator pod (Job Index 0, Pod Index 0) to avoid duplicate logs from other workers)
./gcluster job logs qwen-mt-to-hf --main-only -f
# The trained model is now available in gs://${GCS_BUCKET}/${MODEL_NAME}/hf-trained/
# [END hypercomputer_tpu_tune_qwen3_30b_rl_convert_hf_logs]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_verify_hf_weights]
gcloud storage ls -l --readable-sizes "gs://${GCS_BUCKET}/${MODEL_NAME}/hf-trained/"
# [END hypercomputer_tpu_tune_qwen3_30b_rl_verify_hf_weights]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_cleanup_storage_v2]
./gcluster destroy "${CLUSTER_NAME}"
gcloud storage rm -r "gs://${GCS_BUCKET}"

# To delete the local deployment folder and copied blueprint
rm -rf .ghpc "${CLUSTER_NAME}" gke-tpu-v6e-advanced.yaml
# [END hypercomputer_tpu_tune_qwen3_30b_rl_cleanup_storage_v2]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_yaml_service_account]
  - id: node_pool_service_account
    source: modules/project/service-account
    settings:
      name: gke-np-sa
      project_roles:
      - logging.logWriter
      - monitoring.metricWriter
      - monitoring.viewer
      - stackdriver.resourceMetadata.writer
      - storage.admin
      - artifactregistry.reader
# [END hypercomputer_tpu_tune_qwen3_30b_rl_yaml_service_account]
