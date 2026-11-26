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

: "${PROJECT_ID:?PROJECT_ID must be set (see 0_env.sh)}"
: "${REGION:?REGION must be set (see 0_env.sh)}"
: "${ZONE:?ZONE must be set (see 0_env.sh)}"
: "${CLUSTER_NAME:?CLUSTER_NAME must be set (see 0_env.sh)}"
: "${BUCKET_NAME:?BUCKET_NAME must be set (see 0_env.sh)}"
: "${RESERVATION_NAME:?RESERVATION_NAME must be set (see 0_env.sh)}"
: "${CLUSTER_TOOLKIT_VERSION:?CLUSTER_TOOLKIT_VERSION must be set (see 0_env.sh)}"
: "${NODE_COUNT:=2}"
: "${AUTHORIZED_CIDR:=0.0.0.0/0}"

echo "Downloading Cluster Toolkit ${CLUSTER_TOOLKIT_VERSION}..."
if [[ ! -x "cluster-toolkit/gcluster" ]]; then
# [START hypercomputer_gpu_train_qwen_megatron_gke_toolkit_download]
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
./gcluster --version
# [END hypercomputer_gpu_train_qwen_megatron_gke_toolkit_download]
else
  echo "Cluster Toolkit already downloaded in ./cluster-toolkit."
  cd cluster-toolkit
  ./gcluster --version
fi

echo "Creating the Cloud Storage bucket for the Terraform state..."
if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} already exists. Ensuring versioning is enabled..."
  gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning
else
# [START hypercomputer_gpu_train_qwen_megatron_gke_tf_bucket_create]
gcloud storage buckets create "gs://${BUCKET_NAME:?}" \
  --project="${PROJECT_ID:?}" \
  --location="${REGION:?}" \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access
gcloud storage buckets update "gs://${BUCKET_NAME:?}" --versioning
# [END hypercomputer_gpu_train_qwen_megatron_gke_tf_bucket_create]
fi

echo "Configuring the Cluster Toolkit deployment file..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_deployment_configure]
cat <<EOF > examples/gke-a4/gke-a4-deployment.yaml
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: ${BUCKET_NAME:?}
vars:
  project_id: ${PROJECT_ID:?}
  deployment_name: ${CLUSTER_NAME:?}
  region: ${REGION:?}
  zone: ${ZONE:?}
  static_node_count: ${NODE_COUNT}
  authorized_cidr: "${AUTHORIZED_CIDR}"
  reservation_affinity:
    consume_reservation_type: SPECIFIC_RESERVATION
    specific_reservations:
    - name: ${RESERVATION_NAME:?}
EOF
# [END hypercomputer_gpu_train_qwen_megatron_gke_deployment_configure]

echo "Deploying the A4 GKE cluster (this takes ~18-20 minutes)..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_cluster_create]
./gcluster deploy \
  --download-dependencies \
  -d examples/gke-a4/gke-a4-deployment.yaml \
  examples/gke-a4/gke-a4.yaml \
  --auto-approve -w
# [END hypercomputer_gpu_train_qwen_megatron_gke_cluster_create]

echo "Fetching cluster credentials and verifying cluster readiness..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME:?}" \
  --region="${REGION:?}" \
  --project="${PROJECT_ID:?}"
# [START_EXCLUDE silent]
echo "Waiting for the gIB NCCL installer, RDMA ResourceClaimTemplate, Kueue queues, and Cloud Storage FUSE PVCs..."
LIMIT=60
count=0
until kubectl get daemonset/nccl-rdma-installer -n kube-system >/dev/null 2>&1 && \
      kubectl get resourceclaimtemplate default-rdma >/dev/null 2>&1 && \
      kubectl get localqueue a4 >/dev/null 2>&1 && \
      [[ -n "$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].metadata.name}' 2>/dev/null || true)" ]] && \
      [[ -n "$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].metadata.name}' 2>/dev/null || true)" ]]; do
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for cluster add-ons and PVCs to be created." >&2
    kubectl get daemonset -n kube-system >&2 || true
    kubectl get resourceclaimtemplate,clusterqueue,localqueue,pvc >&2 || true
    exit 1
  fi
  sleep 5
  count=$((count + 1))
done
kubectl rollout status daemonset/nccl-rdma-installer -n kube-system --timeout=900s
kubectl -n jobset-system wait --for=condition=Available deployment --all --timeout=300s
kubectl -n kueue-system wait --for=condition=Available deployment --all --timeout=300s
# [END_EXCLUDE]
kubectl get nodes -l cloud.google.com/gke-nodepool=a4-highgpu-8g-a4-pool -o wide
kubectl get daemonset nccl-rdma-installer -n kube-system
kubectl get resourceclaimtemplate default-rdma
kubectl get clusterqueue,localqueue
kubectl get pvc
# [END hypercomputer_gpu_train_qwen_megatron_gke_cluster_get_creds]

echo "Success! Cluster ${CLUSTER_NAME} is ready."
