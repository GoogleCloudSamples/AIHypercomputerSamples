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

# [START hypercomputer_tpu_sft_gcluster_cb_env]
export PROJECT="YOUR_PROJECT_ID"
export REGION="YOUR_REGION"
export REPOSITORY_NAME="YOUR_REPOSITORY_NAME"
export CLOUD_IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT}/${REPOSITORY_NAME}/maxtext_base:latest"
# [END hypercomputer_tpu_sft_gcluster_cb_env]

# [START hypercomputer_tpu_sft_gcluster_cb_kubectl_install]
gcloud components install kubectl gke-gcloud-auth-plugin --quiet
# [END hypercomputer_tpu_sft_gcluster_cb_kubectl_install]

# [START hypercomputer_tpu_sft_gcluster_create_role]
# The GKE TPU v6e blueprint uses GCS Fuse CSI Storage Profiles which requires a custom IAM role.
# If this role is not already created in your project, you must create it before deploying.
gcloud iam roles create gke.gcsfuse.profileUser \
  --project=${PROJECT} \
  --title="GKE GCSFuse Profile User" \
  --description="Allows scanning GCS buckets for objects, retrieving bucket metadata, and creating Anywhere Caches." \
  --permissions="storage.objects.list,storage.buckets.get,storage.anywhereCaches.create,storage.anywhereCaches.get,storage.anywhereCaches.list,storage.anywhereCaches.update"


# [END hypercomputer_tpu_sft_gcluster_create_role]

# [START hypercomputer_tpu_sft_gcluster_create_cluster]
./gcluster deploy examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml \
    --vars "project_id=${PROJECT},deployment_name=${CLUSTER_NAME},region=${REGION},zone=${ZONE},num_slices=1,tpu_topology=4x8,authorized_cidr=0.0.0.0/0,reservation=${RESERVATION:-}" \
    --download-dependencies \
    -w
# [END hypercomputer_tpu_sft_gcluster_create_cluster]

# [START hypercomputer_tpu_sft_gcluster_configure_docker]
# Configure docker for pulling images
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
# [END hypercomputer_tpu_sft_gcluster_configure_docker]

# [START hypercomputer_tpu_sft_gcluster_convert_model_logs]
# Use the list command to check status
./gcluster job list \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION}

# Check progress of the job (--main-only targets the coordinator pod (Job Index 0, Pod Index 0) to avoid duplicate logs from other workers)
./gcluster job logs hf-to-mt --main-only -f \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION}
# [END hypercomputer_tpu_sft_gcluster_convert_model_logs]

# [START hypercomputer_tpu_sft_gcluster_train_logs]
# Use the list command to check status
./gcluster job list \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION}

# Check progress of the job (--main-only targets the coordinator pod (Job Index 0, Pod Index 0) to avoid duplicate logs from other workers)
./gcluster job logs sft --main-only -f \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION}
# [END hypercomputer_tpu_sft_gcluster_train_logs]

# [START hypercomputer_tpu_sft_gcluster_convert_hf_logs]
# Use the list command to check status
./gcluster job list \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION}

# Check progress of the job (--main-only targets the coordinator pod (Job Index 0, Pod Index 0) to avoid duplicate logs from other workers)
./gcluster job logs mt-to-hf --main-only -f \
    --cluster ${CLUSTER_NAME} \
    --project ${PROJECT} \
    --location ${REGION}

# The trained model is now available in gs://${GCS_BUCKET}/${MODEL_NAME}/hf-trained/ - though again, it's ~2x the size of the original...
# [END hypercomputer_tpu_sft_gcluster_convert_hf_logs]

# [START hypercomputer_tpu_sft_gcluster_cleanup_storage]
gcluster destroy ${CLUSTER_NAME} --robust
gcloud storage rm -r gs://${GCS_BUCKET}
gcloud artifacts repositories delete ${REPOSITORY_NAME} --location=${REGION} --project=${PROJECT} --quiet

# To delete the local deployment folder
rm -rf .ghpc ${CLUSTER_NAME}
# [END hypercomputer_tpu_sft_gcluster_cleanup_storage]

# [START hypercomputer_tpu_sft_gcluster_yaml_service_account]
  - id: node_pool_service_account
    source: modules/project/service-account
    settings:
      name: gke-np-sa
      project_roles:
      - logging.logWriter
      - monitoring.metricWriter
      - monitoring.viewer
      - stackdriver.resourceMetadata.writer
      - storage.admin            # Change from storage.objectViewer
      - artifactregistry.reader
# [END hypercomputer_tpu_sft_gcluster_yaml_service_account]
