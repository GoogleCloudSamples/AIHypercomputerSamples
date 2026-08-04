#!/bin/bash
#
#   Copyright 2026 Google LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_NAME="${USER}-serving-llama-4-a4"
REPO_NAME=$(basename "${ARTIFACT_REGISTRY}")

echo "=============================================================================="
echo "STARTING COMPLETE CLEANUP OF LLAMA 4 / B200 INFRASTRUCTURE"
echo "Project:     ${PROJECT_ID}"
echo "Region/Zone: ${REGION} / ${ZONE}"
echo "Cluster:     ${CLUSTER_NAME}"
echo "Node Pool:   ${NODE_POOL_NAME}"
echo "Bucket:      gs://${GCS_BUCKET}"
echo "Repository:  ${REPO_NAME}"
echo "=============================================================================="

read -p "Are you sure you want to delete ALL these resources? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "--------------------------------------------------------"
echo "Step 0 : Removing port forwarding on port 8000"
echo "--------------------------------------------------------"

pkill -9 -f "kubectl" 2>/dev/null || true
wait 2>/dev/null || true

echo "✓ Port forwarding removed."

echo "--------------------------------------------------------"
echo "Step 1: Removing Helm Release and Kubernetes Resources"
echo "--------------------------------------------------------"

if gcloud container clusters describe "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Fetching credentials for cluster cleanup..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "${PROJECT_ID}" --quiet 2>/dev/null || true

    echo "Uninstalling Helm release: ${RELEASE_NAME}..."
    helm uninstall "${RELEASE_NAME}" 2>/dev/null || true

    echo "Deleting deployments and secrets..."
    kubectl delete deployment -l "app.kubernetes.io/instance=${RELEASE_NAME}" --force --grace-period=0 2>/dev/null || true
    kubectl delete configmap "${RELEASE_NAME}-launcher" "${RELEASE_NAME}-config" 2>/dev/null || true
    kubectl delete secret hf-secret 2>/dev/null || true
    echo "✓ Kubernetes workloads cleaned up."
else
    echo "✓ Cluster not active or inaccessible. Skipping K8s workloads cleanup."
fi

echo "--------------------------------------------------------"
echo "Step 2: Deleting GKE Node Pool (${NODE_POOL_NAME})"
echo "--------------------------------------------------------"

if gcloud container node-pools describe "$NODE_POOL_NAME" --cluster "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting node pool '${NODE_POOL_NAME}' (releasing B200 GPUs)..."
# [START hypercomputer_gpu_infer_llama4scout_a4_delete_node_pool]
    gcloud container node-pools delete "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --region="${CLUSTER_REGION}" \
        --project="${PROJECT_ID}" \
        --quiet
# [END hypercomputer_gpu_infer_llama4scout_a4_delete_node_pool]

    echo "✓ Node pool deleted."
else
    echo "✓ Node pool '${NODE_POOL_NAME}' does not exist."
fi

echo "--------------------------------------------------------"
echo "Step 3: Deleting GKE Cluster (${CLUSTER_NAME})"
echo "--------------------------------------------------------"

if gcloud container clusters describe "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting GKE Cluster '${CLUSTER_NAME}'..."
# [START hypercomputer_gpu_infer_llama4scout_a4_delete_gke_cluster]
    gcloud container clusters delete "${CLUSTER_NAME}" \
        --region="${CLUSTER_REGION}" \
        --project="${PROJECT_ID}" \
        --quiet
# [END hypercomputer_gpu_infer_llama4scout_a4_delete_gke_cluster]

    echo "✓ Cluster deleted."
else
    echo "✓ Cluster '${CLUSTER_NAME}' does not exist."
fi

echo "--------------------------------------------------------"
echo "Step 4: Deleting Artifact Registry Repository (${REPO_NAME})"
echo "--------------------------------------------------------"

if gcloud artifacts repositories describe "${REPO_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Deleting Artifact Registry repository '${REPO_NAME}' and all container images..."
# [START hypercomputer_gpu_infer_llama4scout_a4_delete_ar]
    gcloud artifacts repositories delete "${REPO_NAME}" \
        --location="${REGION}" \
        --project="${PROJECT_ID}" \
        --quiet
# [END hypercomputer_gpu_infer_llama4scout_a4_delete_ar]

    echo "✓ Artifact Registry repository deleted."
else
    echo "✓ Artifact Registry repository '${REPO_NAME}' does not exist."
fi

echo "--------------------------------------------------------"
echo "Step 5: Deleting Cloud Storage Bucket (gs://${GCS_BUCKET})"
echo "--------------------------------------------------------"

if gcloud storage buckets describe "gs://${GCS_BUCKET}" >/dev/null 2>&1; then
    echo "Cleaning bucket contents and deleting gs://${GCS_BUCKET}..."
    gcloud storage rm --recursive "gs://${GCS_BUCKET}" --quiet 2>/dev/null || true
    echo "✓ Bucket deleted."
else
    echo "✓ Bucket gs://${GCS_BUCKET} does not exist."
fi

echo "--------------------------------------------------------"
echo "Step 6: Cleaning Local Workspace Files"
echo "--------------------------------------------------------"

BUILD_DIR="${SCRIPT_DIR}/build_b200"
if [[ -d "$BUILD_DIR" ]]; then
    rm -rf "$BUILD_DIR"
    echo "✓ Deleted local build directory: ${BUILD_DIR}"
fi

echo "=============================================================================="
echo "CLEANUP COMPLETED SUCCESSFULLY!"
echo "All GKE clusters, B200 node pools, Docker artifacts, and GCS buckets removed."
echo "=============================================================================="
