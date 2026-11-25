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

echo "[$(date)] ==================== Creating Cloud Storage buckets... ===================="
if gcloud storage buckets describe "gs://$TF_STATE_BUCKET" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Bucket gs://${TF_STATE_BUCKET} already exists. Skipping creation."
else
  # [START hypercomputer_tpu_train_muse_glimmer_30b_create_state_bucket]
  gcloud storage buckets create "gs://$TF_STATE_BUCKET" --project="$PROJECT_ID" --location="$REGION" --uniform-bucket-level-access
  gcloud storage buckets update "gs://$TF_STATE_BUCKET" --versioning
  # [END hypercomputer_tpu_train_muse_glimmer_30b_create_state_bucket]
fi

if gcloud storage buckets describe "gs://$BUCKET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} already exists. Skipping creation."
else
  # [START hypercomputer_tpu_train_muse_glimmer_30b_create_output_bucket]
  gcloud storage buckets create "gs://$BUCKET_NAME" --project="$PROJECT_ID" --location="$REGION" --uniform-bucket-level-access
  # [END hypercomputer_tpu_train_muse_glimmer_30b_create_output_bucket]
fi

echo "[$(date)] ==================== Writing the deployment file... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_deployment_file]
cat > "${CLUSTER_NAME}-deployment.yaml" <<EOF
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: ${TF_STATE_BUCKET}
vars:
  project_id: ${PROJECT_ID}
  deployment_name: ${CLUSTER_NAME}
  region: ${REGION}
  zone: ${ZONE}
  num_slices: 1
  machine_type: ct6e-standard-4t
  tpu_topology: ${TOPOLOGY}
  authorized_cidr: 0.0.0.0/0
  enable_pathways_for_tpus: false
  reservation_affinity:
    consume_reservation_type: SPECIFIC_RESERVATION
    specific_reservations:
    - name: ${RESERVATION_NAME}
EOF
# [END hypercomputer_tpu_train_muse_glimmer_30b_deployment_file]

echo "[$(date)] ==================== Deploying the cluster with Cluster Toolkit... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_deploy_cluster]
cp examples/gke-tpu-v6e/gke-tpu-v6e.yaml gke-tpu-v6e.yaml
sed -i '/- id: gke-tpu-v6e-cluster/,/settings:/ s/^\( *\)settings:$/&\n\1  enable_gcsfuse_csi: true/' gke-tpu-v6e.yaml
./gcluster deploy -d "${CLUSTER_NAME}-deployment.yaml" gke-tpu-v6e.yaml --download-dependencies --auto-approve
# [END hypercomputer_tpu_train_muse_glimmer_30b_deploy_cluster]

echo "[$(date)] ==================== Configuring cluster access... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_get_credentials]
gcloud container clusters get-credentials "$CLUSTER_NAME" --location "$REGION" --project "$PROJECT_ID"
# [END hypercomputer_tpu_train_muse_glimmer_30b_get_credentials]

# [START hypercomputer_tpu_train_muse_glimmer_30b_grant_ksa_bucket_access]
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/default/sa/default" \
  --role=roles/storage.objectUser
# [END hypercomputer_tpu_train_muse_glimmer_30b_grant_ksa_bucket_access]

# [START hypercomputer_tpu_train_muse_glimmer_30b_grant_node_sa_bucket_access]
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role=roles/storage.objectUser
# [END hypercomputer_tpu_train_muse_glimmer_30b_grant_node_sa_bucket_access]

echo "[$(date)] ==================== Waiting for ${NNODES} TPU nodes to be Ready... ===================="
LIMIT=90
count=0
while true; do
  READY_NODES=$(kubectl get nodes -l "cloud.google.com/gke-tpu-topology=${TOPOLOGY}" --no-headers 2>/dev/null | awk '$2 == "Ready"' | wc -l || true)
  if [ "${READY_NODES}" -ge "${NNODES}" ]; then
    echo "All ${READY_NODES} TPU nodes are Ready."
    break
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Timeout waiting for TPU nodes: ${READY_NODES}/${NNODES} Ready." >&2
    kubectl get nodes -L cloud.google.com/gke-tpu-topology >&2 || true
    exit 1
  fi
  echo "TPU nodes Ready: ${READY_NODES}/${NNODES}. Waiting 20s..."
  sleep 20
  count=$((count + 1))
done

# [START hypercomputer_tpu_train_muse_glimmer_30b_check_nodes]
kubectl get nodes -L cloud.google.com/gke-tpu-topology
# [END hypercomputer_tpu_train_muse_glimmer_30b_check_nodes]

echo "Waiting for JobSet and Kueue controllers to be ready..."
kubectl -n jobset-system rollout status deployment/jobset-controller-manager --timeout=300s
kubectl -n kueue-system rollout status deployment/kueue-controller-manager --timeout=300s

echo "[$(date)] ==================== Cluster setup completed. ===================="
