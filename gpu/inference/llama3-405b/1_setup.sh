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

# Define version
terraform_version="1.12.2"
install_temp_dir="/tmp/bin_dependencies"
mkdir -p "${install_temp_dir}"

# Install Terraform
if ! command -v terraform >/dev/null 2>&1; then
  echo "[$(date)] Installing Terraform..."
  curl -f -s -L \
    -o "${install_temp_dir}/terraform.zip" \
    "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
  python3 -m zipfile -e "${install_temp_dir}/terraform.zip" "${install_temp_dir}"
  sudo mv "${install_temp_dir}/terraform" /usr/local/bin/
  sudo chmod +x /usr/local/bin/terraform
  rm -f "${install_temp_dir}/terraform.zip"
fi

# Install Helm
if ! command -v helm >/dev/null 2>&1; then
  echo "[$(date)] Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "[$(date)] ==================== Installing Cluster Toolkit... ===================="
if [[ ! -x "cluster-toolkit/gcluster" ]]; then
  # [START hypercomputer_gpu_infer_llama3_405b_install_cluster_toolkit]
  TAG="${CLUSTER_TOOLKIT_VERSION:-v1.104.0}"
  OS="linux"
  ARCH="amd64"
  mkdir -p cluster-toolkit && curl -L "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${TAG}/gcluster_bundle_${OS}_${ARCH}.tgz" | tar -xz -C cluster-toolkit
  # [END hypercomputer_gpu_infer_llama3_405b_install_cluster_toolkit]
else
  echo "Cluster Toolkit already downloaded in ./cluster-toolkit."
fi

echo "[$(date)] ==================== Creating Terraform state GCS bucket... ===================="
if ! gcloud storage buckets describe "gs://${GCS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  # [START hypercomputer_gpu_infer_llama3_405b_create_tf_bucket]
  gcloud storage buckets create "gs://${GCS_BUCKET}" \
      --default-storage-class=STANDARD \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access
  gcloud storage buckets update "gs://${GCS_BUCKET}" --versioning
  # [END hypercomputer_gpu_infer_llama3_405b_create_tf_bucket]
else
  echo "Bucket gs://${GCS_BUCKET} already exists."
fi

echo "[$(date)] ==================== Configuring gke-a4 deployment blueprint... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_configure_blueprint]
cat <<EOF > cluster-toolkit/examples/gke-a4/gke-a4-deployment.yaml
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: ${GCS_BUCKET}

vars:
  project_id: ${PROJECT_ID}
  deployment_name: ${CLUSTER_NAME}
  region: ${REGION}
  zone: ${ZONE}
  static_node_count: 2
  authorized_cidr: 0.0.0.0/0
  reservation_affinity:
    consume_reservation_type: SPECIFIC_RESERVATION
    specific_reservations:
    - name: ${RESERVATION_NAME}
EOF
# [END hypercomputer_gpu_infer_llama3_405b_configure_blueprint]

echo "[$(date)] ==================== Deploying GKE A4 cluster ${CLUSTER_NAME} with Cluster Toolkit... ===================="
(
  cd cluster-toolkit
# [START hypercomputer_gpu_infer_llama3_405b_cluster_create]
./gcluster deploy \
    -d examples/gke-a4/gke-a4-deployment.yaml \
    examples/gke-a4/gke-a4.yaml \
    --auto-approve -w
# [END hypercomputer_gpu_infer_llama3_405b_cluster_create]
)

echo "[$(date)] ==================== Getting cluster credentials... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}"
# [END hypercomputer_gpu_infer_llama3_405b_cluster_get_creds]

echo "[$(date)] ==================== Creating hf-secret secret... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_llama3_405b_secret_create]

echo "[$(date)] ==================== Installing KAI Scheduler and Dynamo Platform... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_install_dynamo]
RELEASE_VERSION="${DYNAMO_RELEASE_VERSION:-1.5.0}"
helm fetch "https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${RELEASE_VERSION}.tgz"
tar -zxf "dynamo-platform-${RELEASE_VERSION}.tgz"

helm upgrade --install kai-scheduler ./dynamo-platform/charts/kai-scheduler \
    --set scheduler.args.default-staleness-grace-period="-1s" \
    --set topologyMigration.enabled=false

kubectl wait --for=condition=Available deployment/kai-operator --timeout=120s
until kubectl get deployment/queue-controller >/dev/null 2>&1; do sleep 2; done
kubectl wait --for=condition=Available deployment/queue-controller --timeout=120s

helm upgrade --install dynamo-platform ./dynamo-platform \
    --set global.grove.install=true \
    --set global.grove.enabled=true \
    --set global.kai-scheduler.enabled=true
# [END hypercomputer_gpu_infer_llama3_405b_install_dynamo]

echo "Waiting for Dynamo operator and Grove operator deployments to become Available..."
kubectl wait --for=condition=Available deployment/dynamo-platform-dynamo-operator-controller-manager --timeout=300s || true
kubectl wait --for=condition=Available deployment/grove-operator --timeout=300s || true

echo "[$(date)] ==================== Cluster and Dynamo setup completed! ===================="
