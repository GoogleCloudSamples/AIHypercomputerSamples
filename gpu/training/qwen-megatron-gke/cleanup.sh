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

set -uo pipefail

# Capture the GKE cluster hash before deletion so any org-enforced firewall rules
# attached to GKE accelerator network profile (ANP) VPCs (gke-anp-<hash>-*) can
# be cleared if they block node pool or cluster deletion.
CLUSTER_HASH=""
CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" \
  --location="${REGION}" --project="${PROJECT_ID}" --format="value(id)" 2>/dev/null || true)
if [[ -n "${CLUSTER_ID}" ]]; then
  CLUSTER_HASH="${CLUSTER_ID:0:8}"
fi

echo "Deleting Kubernetes workloads and Cloud Storage FUSE dataset/checkpoint objects..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_workload_cleanup]
export TRAINING_BUCKET="${TRAINING_BUCKET:-$(kubectl get pv -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].spec.csi.volumeHandle}' 2>/dev/null || true)}"
export CHECKPOINT_BUCKET="${CHECKPOINT_BUCKET:-$(kubectl get pv -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].spec.csi.volumeHandle}' 2>/dev/null || true)}"
kubectl delete jobset -l kueue.x-k8s.io/queue-name=a4 --ignore-not-found || true
kubectl delete job qwen3-data-prep --ignore-not-found || true
if [[ -n "${TRAINING_BUCKET}" ]]; then
  gcloud storage rm --recursive "gs://${TRAINING_BUCKET}/dataset" "gs://${TRAINING_BUCKET}/tokenizer" || true
fi
if [[ -n "${CHECKPOINT_BUCKET}" ]]; then
  gcloud storage rm --recursive "gs://${CHECKPOINT_BUCKET}/qwen3-30b-a3b" "gs://${CHECKPOINT_BUCKET}/data-cache" "gs://${CHECKPOINT_BUCKET}/tb-logs" || true
fi
# [END hypercomputer_gpu_train_qwen_megatron_gke_workload_cleanup]

# Continuously clear org-enforced firewall rules on VPC and GKE ANP networks so
# Terraform and GKE teardown are not blocked.
FW_FILTER="network:${CLUSTER_NAME}-net-0${CLUSTER_HASH:+ OR network ~ gke-anp-${CLUSTER_HASH} OR name ~ ${CLUSTER_HASH}}"
(
  while true; do
    gcloud compute firewall-rules list --project="${PROJECT_ID}" \
      --filter="${FW_FILTER}" --format="value(name)" 2>/dev/null \
      | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
    sleep 3
  done
) &
FW_WATCHER_PID=$!
trap 'kill "${FW_WATCHER_PID}" 2>/dev/null || true' EXIT

echo "Destroying the Cluster Toolkit deployment..."
if [[ -d "cluster-toolkit/${CLUSTER_NAME}" && -x "cluster-toolkit/gcluster" ]]; then
  cd cluster-toolkit
  if ! (
# [START hypercomputer_gpu_train_qwen_megatron_gke_cluster_cleanup]
./gcluster destroy "${CLUSTER_NAME:?}" --robust --auto-approve
# [END hypercomputer_gpu_train_qwen_megatron_gke_cluster_cleanup]
  ); then
    echo "gcluster destroy failed. Removing the GKE cluster with gcloud and retrying..." >&2
    if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
      gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet || true
    fi
    ./gcluster destroy "${CLUSTER_NAME}" --robust --auto-approve || true
  fi
  cd ..
else
  echo "Deployment directory cluster-toolkit/${CLUSTER_NAME} not found. Checking for live GKE cluster..." >&2
  if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet || true
  fi
fi

# Clean up any dangling GKE ANP subnets and networks.
if [[ -n "${CLUSTER_HASH}" ]]; then
  gcloud compute networks subnets list --project="${PROJECT_ID}" --regions="${REGION}" \
    --filter="network ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute networks subnets delete --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud compute networks list --project="${PROJECT_ID}" \
    --filter="name ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute networks delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

kill "${FW_WATCHER_PID}" 2>/dev/null || true

if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
# [START hypercomputer_gpu_train_qwen_megatron_gke_tf_bucket_cleanup]
gcloud storage rm --recursive "gs://${BUCKET_NAME:?}"
# [END hypercomputer_gpu_train_qwen_megatron_gke_tf_bucket_cleanup]
fi

rm -rf cluster-toolkit pretrain_run1_node0.log pretrain_run1_node1.log
echo "Cleanup completed."
