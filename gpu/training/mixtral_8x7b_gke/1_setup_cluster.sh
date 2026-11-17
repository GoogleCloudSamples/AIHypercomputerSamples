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

echo "Downloading Cluster Toolkit ${CLUSTER_TOOLKIT_VERSION}..."
# [START hypercomputer_gpu_train_mixtral_8x7b_install_ctk]
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              BUNDLE="gcluster_bundle_linux_amd64.tgz" ;;
  Linux-aarch64|Linux-arm64) BUNDLE="gcluster_bundle_linux_arm64.tgz" ;;
  Darwin-x86_64)             BUNDLE="gcluster_bundle_mac_amd64.tgz" ;;
  Darwin-arm64)              BUNDLE="gcluster_bundle_mac_arm64.tgz" ;;
  *) BUNDLE=""; echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2 ;;
esac
mkdir -p cluster-toolkit
curl -fsSL "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION:?}/${BUNDLE:?}" \
  | tar -xz -C cluster-toolkit
cd cluster-toolkit
# [END hypercomputer_gpu_train_mixtral_8x7b_install_ctk]

# [START hypercomputer_gpu_train_mixtral_8x7b_verify_ctk]
./gcluster --version
ls -la examples/gke-a4/
# [END hypercomputer_gpu_train_mixtral_8x7b_verify_ctk]

echo "Creating the Cloud Storage bucket for Terraform state..."
if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} already exists. Ensuring versioning is enabled..."
  gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning
else
# [START hypercomputer_gpu_train_mixtral_8x7b_create_tf_bucket]
gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning
# [END hypercomputer_gpu_train_mixtral_8x7b_create_tf_bucket]
fi

echo "Populating examples/gke-a4/gke-a4-deployment.yaml..."
# [START hypercomputer_gpu_train_mixtral_8x7b_configure_deployment]
cat <<EOF > examples/gke-a4/gke-a4-deployment.yaml
terraform_backend_defaults:
  type: gcs
  configuration:
    # The Cloud Storage bucket used for storing Terraform state
    bucket: ${BUCKET_NAME}

vars:
  # Your Google Cloud project ID
  project_id: ${PROJECT_ID}

  # This should be unique across all of your Cluster
  # Toolkit deployments.
  deployment_name: ${CLUSTER_NAME}

  # The Google Cloud region used for this deployment.
  region: ${REGION}

  # The Google Cloud zone used for this deployment.
  zone: ${ZONE}

  # The number of nodes to be created.
  static_node_count: ${NODE_COUNT}

  # CIDR block containing the IP of the machine calling Terraform.
  # To allow all (IAM restrictions still enforced), use 0.0.0.0/0
  # To allow only your IP address, use <YOUR-IP-ADDRESS>/32
  authorized_cidr: "${AUTHORIZED_CIDR}"

  # The name of the Compute Engine reservation in the form of
  # <reservation-name>
  # To target a BLOCK_NAME, the name of the extended reservation can be
  # entered as <reservation-name>/reservationBlocks/<reservation-block-name>
  reservation: ${RESERVATION_NAME}
EOF
# [END hypercomputer_gpu_train_mixtral_8x7b_configure_deployment]

# [START hypercomputer_gpu_train_mixtral_8x7b_force_destroy]
sed -i 's/force_destroy: false/force_destroy: true/g' examples/gke-a4/gke-a4.yaml
# [END hypercomputer_gpu_train_mixtral_8x7b_force_destroy]

echo "Deploying the A4 GKE cluster (~15-20 minutes)..."
# [START hypercomputer_gpu_train_mixtral_8x7b_deploy_cluster]
./gcluster deploy \
  --skip-validators=test_gcsfuse_iam_role_exists \
  -d examples/gke-a4/gke-a4-deployment.yaml \
  examples/gke-a4/gke-a4.yaml \
  --auto-approve
# [END hypercomputer_gpu_train_mixtral_8x7b_deploy_cluster]

# [START hypercomputer_gpu_train_mixtral_8x7b_get_credentials]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"
# [END hypercomputer_gpu_train_mixtral_8x7b_get_credentials]

echo "Waiting for JobSet controller and gIB NCCL installer to roll out..."
kubectl rollout status deployment/jobset-controller -n jobset-system --timeout=300s
kubectl rollout status daemonset/nccl-rdma-installer -n kube-system --timeout=900s

# [START hypercomputer_gpu_train_mixtral_8x7b_verify_cluster]
kubectl get nodes -l cloud.google.com/gke-nodepool=a4-highgpu-8g-a4-pool -o wide
kubectl get daemonset nccl-rdma-installer -n kube-system
kubectl get resourceclaimtemplate default-rdma
kubectl get clusterqueue,localqueue
kubectl get pvc
# [END hypercomputer_gpu_train_mixtral_8x7b_verify_cluster]

echo "Cluster ${CLUSTER_NAME} is ready."
