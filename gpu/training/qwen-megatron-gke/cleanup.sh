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

# Clear org-enforced firewall rules strictly on GKE ANP networks (gke-anp-<hash>-*).
# Do NOT target ${CLUSTER_NAME}-net-0 here: `gcluster destroy --robust` already deletes
# firewall rules on ${CLUSTER_NAME}-net-0, and deleting them concurrently causes GCE
# Error 400 (resourceNotReady) in gcluster destroy.
FW_WATCHER_PID=""
stop_fw_watcher() {
  if [[ -n "${FW_WATCHER_PID}" ]]; then
    kill "${FW_WATCHER_PID}" 2>/dev/null || true
    wait "${FW_WATCHER_PID}" 2>/dev/null || true
    FW_WATCHER_PID=""
  fi
}
trap stop_fw_watcher EXIT

if [[ -n "${CLUSTER_HASH}" ]]; then
  (
    while true; do
      gcloud compute firewall-rules list --project="${PROJECT_ID}" \
        --filter="network ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null \
        | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
      sleep 3
    done
  ) &
  FW_WATCHER_PID=$!
fi

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
    # Stop the ANP watcher once the GKE cluster is deleted so gcluster destroy retries cleanly.
    stop_fw_watcher
    for attempt in 1 2; do
      if ./gcluster destroy "${CLUSTER_NAME:?}" --robust --auto-approve; then
        break
      fi
      echo "gcluster destroy retry ${attempt} failed; waiting 15s before retrying..." >&2
      sleep 15
    done
  fi
  cd ..
else
  echo "Deployment directory cluster-toolkit/${CLUSTER_NAME} not found. Checking for live GKE cluster..." >&2
  if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet || true
  fi
fi

stop_fw_watcher

# Clean up any dangling GKE ANP subnets, firewall rules, and networks.
if [[ -n "${CLUSTER_HASH}" ]]; then
  gcloud compute firewall-rules list --project="${PROJECT_ID}" \
    --filter="network ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud compute networks subnets list --project="${PROJECT_ID}" --regions="${REGION}" \
    --filter="network ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute networks subnets delete --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud compute networks list --project="${PROJECT_ID}" \
    --filter="name ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute networks delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

# Fallback sweep for any dangling Cluster Toolkit VPC, router, NAT IPs, or service accounts.
if gcloud compute routers describe "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  for nat in $(gcloud compute routers nats list --router="${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --format="value(name)" 2>/dev/null || true); do
    gcloud compute routers nats delete "${nat}" --router="${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  done
  gcloud compute routers delete "${CLUSTER_NAME}-net-0-router" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

NAT_IPS=$(gcloud compute addresses list --project="${PROJECT_ID}" --regions="${REGION}" \
  --filter="name ~ ^${CLUSTER_NAME}-net-0-nat-ips" --format="value(name)" 2>/dev/null || true)
if [[ -n "${NAT_IPS}" ]]; then
  echo "${NAT_IPS}" | xargs -r gcloud compute addresses delete --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

if gcloud compute networks subnets describe "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud compute networks subnets delete "${CLUSTER_NAME}-sub-0" --region="${REGION}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
fi

if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  for attempt in 1 2 3; do
    gcloud compute firewall-rules list --project="${PROJECT_ID}" \
      --filter="network:${CLUSTER_NAME}-net-0" --format="value(name)" 2>/dev/null \
      | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet 2>/dev/null || true
    if gcloud compute networks delete "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" --quiet 2>/dev/null; then
      break
    fi
    sleep 5
  done
fi

for sa in "${CLUSTER_NAME}-gke-np-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
          "${CLUSTER_NAME}-gke-wl-sa@${PROJECT_ID}.iam.gserviceaccount.com"; do
  if gcloud iam service-accounts describe "${sa}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud iam service-accounts delete "${sa}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  fi
done

if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
# [START hypercomputer_gpu_train_qwen_megatron_gke_tf_bucket_cleanup]
gcloud storage rm --recursive "gs://${BUCKET_NAME:?}"
# [END hypercomputer_gpu_train_qwen_megatron_gke_tf_bucket_cleanup]
fi

rm -rf cluster-toolkit pretrain_run1_node0.log pretrain_run1_node1.log
echo "Cleanup completed."
