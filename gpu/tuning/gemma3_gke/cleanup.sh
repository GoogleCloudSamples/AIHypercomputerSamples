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

set -e

kubectl delete job finetune-job --ignore-not-found=true || true
echo "[$(date)] ==================== Job deleted. ===================="

if gcloud container clusters describe "${CLUSTER_NAME}" --region="${CLUSTER_REGION}" >/dev/null 2>&1; then
    gcloud container clusters delete "${CLUSTER_NAME}" \
        --region="${CLUSTER_REGION}" --quiet || true

    if gcloud container clusters describe "${CLUSTER_NAME}" --region="${CLUSTER_REGION}" >/dev/null 2>&1; then
        echo "[$(date)] ==================== Cluster was not deleted. ===================="
    else
        echo "[$(date)] ==================== Cluster deleted. ===================="
    fi
else
    echo "[$(date)] ==================== Cluster ${CLUSTER_NAME} does not exist. ===================="
fi

gcloud artifacts repositories delete gemma \
    --location="${ARTIFACT_REPO_LOCATION}" \
    --quiet || true
echo "[$(date)] ==================== Artifact Registry deleted. ===================="
