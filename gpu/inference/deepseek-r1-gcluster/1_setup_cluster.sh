#!/bin/bash
#
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

: "${CLUSTER_TOOLKIT_VERSION:?CLUSTER_TOOLKIT_VERSION must be set (see 0_env.sh)}"

echo "Downloading Cluster Toolkit ${CLUSTER_TOOLKIT_VERSION}..."
# [START hypercomputer_gpu_infer_deepseek_r1_toolkit_download]
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              BUNDLE="gcluster_bundle_linux_amd64.tgz" ;;
  Linux-aarch64|Linux-arm64) BUNDLE="gcluster_bundle_linux_arm64.tgz" ;;
  Darwin-x86_64)             BUNDLE="gcluster_bundle_mac_amd64.tgz" ;;
  Darwin-arm64)              BUNDLE="gcluster_bundle_mac_arm64.tgz" ;;
  *) BUNDLE=""; echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2 ;;
esac
mkdir -p cluster-toolkit
curl -fsSL "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION}/${BUNDLE:?}" \
  | tar -xz -C cluster-toolkit
cd cluster-toolkit
./gcluster --version
# [END hypercomputer_gpu_infer_deepseek_r1_toolkit_download]

echo "Creating the Cloud Storage bucket for the Terraform state..."
if gcloud storage buckets describe "gs://${TERRAFORM_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Bucket gs://${TERRAFORM_BUCKET} already exists. Skipping creation."
else
# [START hypercomputer_gpu_infer_deepseek_r1_tf_bucket_create]
gcloud storage buckets create "gs://${TERRAFORM_BUCKET}" \
    --default-storage-class=STANDARD \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
# [END hypercomputer_gpu_infer_deepseek_r1_tf_bucket_create]
fi

echo "Configuring the Cluster Toolkit deployment file..."
# [START hypercomputer_gpu_infer_deepseek_r1_deployment_configure]
STATIC_NODES="2"
AUTHORIZED_CIDR="0.0.0.0/0"
sed -i -E \
  -e "s|^([[:space:]]*)#*[[:space:]]*(bucket:)[[:space:]]*.*|\1\2 ${TERRAFORM_BUCKET}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(project_id:)[[:space:]]*.*|\1\2 ${PROJECT_ID}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(deployment_name:)[[:space:]]*.*|\1\2 ${CLUSTER_NAME}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(region:)[[:space:]]*.*|\1\2 ${REGION}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(zone:)[[:space:]]*.*|\1\2 ${ZONE}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(static_node_count:)[[:space:]]*.*|\1\2 ${STATIC_NODES}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(authorized_cidr:)[[:space:]]*.*|\1\2 ${AUTHORIZED_CIDR}|" \
  -e "s|^([[:space:]]*)#*[[:space:]]*(reservation:)[[:space:]]*.*|\1\2 ${RESERVATION_NAME}|" \
  examples/gke-a4/gke-a4-deployment.yaml
# [END hypercomputer_gpu_infer_deepseek_r1_deployment_configure]

echo "Deploying the cluster (this takes ~30-45 minutes)..."
# [START hypercomputer_gpu_infer_deepseek_r1_cluster_create]
./gcluster deploy -d examples/gke-a4/gke-a4-deployment.yaml examples/gke-a4/gke-a4.yaml \
    --download-dependencies \
    --auto-approve -w
# [END hypercomputer_gpu_infer_deepseek_r1_cluster_create]

# [START hypercomputer_gpu_infer_deepseek_r1_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_gpu_infer_deepseek_r1_cluster_get_creds]

echo "Waiting for the JobSet controller and the gIB NCCL installer to be ready..."
LIMIT=60
count=0
until kubectl get deployment/jobset-controller -n jobset-system >/dev/null 2>&1 && \
      kubectl get daemonset/nccl-rdma-installer -n kube-system >/dev/null 2>&1; do
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for the JobSet controller and gIB installer to be created." >&2
    exit 1
  fi
  sleep 5
  count=$((count + 1))
done
kubectl rollout status deployment/jobset-controller -n jobset-system --timeout=300s
kubectl rollout status daemonset/nccl-rdma-installer -n kube-system --timeout=900s

echo "Success! Cluster ${CLUSTER_NAME} is ready for deployment."
