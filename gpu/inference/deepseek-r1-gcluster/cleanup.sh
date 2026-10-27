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

# The A4 node pool attaches GKE accelerator network profile (ANP) VPCs named
# gke-anp-<first 8 chars of the cluster ID>-*. Firewall rules added to these
# networks outside of GKE (for example, by organization policy enforcers) block
# their deletion, which makes node pool and cluster deletion fail.
CLUSTER_HASH=""
CLUSTER_ID=$(gcloud container clusters describe "${CLUSTER_NAME}" \
    --location="${REGION}" --project="${PROJECT_ID}" --format="value(id)" 2>/dev/null || true)
if [ -n "${CLUSTER_ID}" ]; then
  CLUSTER_HASH="${CLUSTER_ID:0:8}"
fi

cleanup_anp_firewalls() {
  if [ -z "${CLUSTER_HASH}" ]; then
    return 0
  fi
  local rules
  rules=$(gcloud compute firewall-rules list --project="${PROJECT_ID}" \
      --filter="network ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null || true)
  if [ -n "${rules}" ]; then
    echo "Deleting firewall rules attached to the ANP networks of ${CLUSTER_NAME}..."
    echo "${rules}" | xargs gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet || true
  fi
}

# [START hypercomputer_gpu_infer_deepseek_r1_workload_cleanup]
envsubst '$MODEL_BUCKET' < deepseek_r1_8k_1k.yaml | kubectl delete -f - --ignore-not-found || true
envsubst '$MODEL_BUCKET' < deepseek_r1_server.yaml | kubectl delete -f - --ignore-not-found || true
kubectl delete job download-deepseek-r1 --ignore-not-found || true
kubectl wait --for=delete pod -l app=vllm-r1 --timeout=120s || true
kubectl delete secret hf-secret --ignore-not-found || true
# [END hypercomputer_gpu_infer_deepseek_r1_workload_cleanup]

if gcloud storage buckets describe "gs://${MODEL_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
# [START hypercomputer_gpu_infer_deepseek_r1_model_bucket_cleanup]
gcloud storage rm --recursive "gs://${MODEL_BUCKET}"
# [END hypercomputer_gpu_infer_deepseek_r1_model_bucket_cleanup]
fi

cleanup_anp_firewalls

if [ -d "cluster-toolkit/${CLUSTER_NAME}" ]; then
  cd cluster-toolkit
  if ! (
# [START hypercomputer_gpu_infer_deepseek_r1_cluster_cleanup]
./gcluster destroy "${CLUSTER_NAME}" --robust --auto-approve
# [END hypercomputer_gpu_infer_deepseek_r1_cluster_cleanup]
  ); then
    echo "gcluster destroy failed. Removing the GKE cluster with gcloud and retrying..." >&2
    cleanup_anp_firewalls
    if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
      gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet || {
        cleanup_anp_firewalls
        gcloud container clusters delete "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT_ID}" --quiet
      }
    fi
    ./gcluster destroy "${CLUSTER_NAME}" --robust --auto-approve
  fi
  cd ..
else
  echo "Deployment directory cluster-toolkit/${CLUSTER_NAME} not found. Skipping gcluster destroy." >&2
fi

# Remove ANP networks left behind if GKE could not delete them.
if [ -n "${CLUSTER_HASH}" ]; then
  cleanup_anp_firewalls
  ANP_NETWORKS=$(gcloud compute networks list --project="${PROJECT_ID}" \
      --filter="name ~ gke-anp-${CLUSTER_HASH}" --format="value(name)" 2>/dev/null || true)
  if [ -n "${ANP_NETWORKS}" ]; then
    echo "${ANP_NETWORKS}" | xargs gcloud compute networks delete --project="${PROJECT_ID}" --quiet || true
  fi
fi

if gcloud storage buckets describe "gs://${TERRAFORM_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
# [START hypercomputer_gpu_infer_deepseek_r1_tf_bucket_cleanup]
gcloud storage rm --recursive "gs://${TERRAFORM_BUCKET}"
# [END hypercomputer_gpu_infer_deepseek_r1_tf_bucket_cleanup]
fi

rm -rf cluster-toolkit
