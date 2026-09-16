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

echo "[$(date)] ==================== Creating Cluster... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_create_cluster]
# Start with creating a new virtual environment to install XPK in.
VENV_DIR="venvp3"
python3 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"
pip install xpk==1.14.0

GKE_VERSION="$(gcloud container get-server-config --region="${REGION}" --flatten="channels" --filter="channels.channel=REGULAR" --format="value(channels.defaultVersion)" 2>/dev/null | head -n1)"
echo "Using GKE version from REGULAR channel: ${GKE_VERSION}"

xpk cluster create-pathways \
  --num-slices="${CLUSTER_NODEPOOL_COUNT}" \
  --tpu-type="${TPU_TYPE}" \
  --pathways-gce-machine-type="${PW_CPU_MACHINE_TYPE}" \
  --project="${PROJECT}" \
  --zone="${ZONE}" \
  --cluster="${CLUSTER_NAME}" \
  --gke-version="${GKE_VERSION}" \
  --custom-cluster-arguments="--enable-ip-alias" \
  --reservation="${RESERVATION}" \
  --default-pool-cpu-machine-type=n4-standard-16 \
  --default-pool-cpu-num-nodes=1

gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --location="${REGION}" \
  --project="${PROJECT}"
# [END hypercomputer_tpu_tune_qwen3_sft_create_cluster]

echo "Waiting for background cluster operations to finish..."
while gcloud container operations list --project="${PROJECT}" --location="${REGION}" --filter="status=RUNNING AND targetLink:${CLUSTER_NAME}" --format="value(name)" 2>/dev/null | grep -q .; do
  sleep 10
done

echo "Waiting for Jobset and Kueue controllers to be ready..."
kubectl wait --for=condition=available --timeout=5m deployment/jobset-controller-manager -n jobset-system
kubectl wait --for=condition=available --timeout=5m deployment/kueue-controller-manager -n kueue-system

echo "[$(date)] ==================== Cluster created. ===================="
