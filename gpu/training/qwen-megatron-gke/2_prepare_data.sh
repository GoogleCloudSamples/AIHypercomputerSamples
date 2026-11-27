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

echo "Discovering Cloud Storage FUSE PersistentVolumeClaims..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_get_pvcs]
export TRAINING_PVC="$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].metadata.name}')"
export CHECKPOINT_PVC="$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].metadata.name}')"
echo "Training PVC:   ${TRAINING_PVC}"
echo "Checkpoint PVC: ${CHECKPOINT_PVC}"
# [END hypercomputer_gpu_train_qwen_megatron_gke_get_pvcs]

: "${TRAINING_PVC:?TRAINING_PVC was not found in the cluster}"
: "${CHECKPOINT_PVC:?CHECKPOINT_PVC was not found in the cluster}"

# Jobs are immutable, so remove any leftover job from a previous run.
kubectl delete job qwen3-data-prep --ignore-not-found

echo "Submitting the tokenized C4 dataset preparation Job..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_data_prep_run]
envsubst '${TRAINING_PVC}' < qwen3-data-prep.yaml | kubectl apply -f -
# [START_EXCLUDE silent]
LIMIT=120
count=0
while true; do
  CONDITIONS=$(kubectl get job qwen3-data-prep -o jsonpath='{.status.conditions[?(@.status=="True")].type}' 2>/dev/null || true)
  if [[ "${CONDITIONS}" == *Complete* ]]; then
    break
  fi
  if [[ "${CONDITIONS}" == *Failed* ]]; then
    echo "Error: job/qwen3-data-prep failed." >&2
    kubectl describe job qwen3-data-prep >&2 || true
    kubectl logs job/qwen3-data-prep -c data-prep >&2 || true
    exit 1
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for job/qwen3-data-prep to complete." >&2
    kubectl describe job qwen3-data-prep >&2 || true
    kubectl describe pod -l job-name=qwen3-data-prep >&2 || true
    exit 1
  fi
  sleep 10
  count=$((count + 1))
done
# [END_EXCLUDE]
kubectl wait --for=condition=complete job/qwen3-data-prep --timeout=1200s
kubectl logs job/qwen3-data-prep -c data-prep
# [END hypercomputer_gpu_train_qwen_megatron_gke_data_prep_run]

echo "Dataset preparation job completed."
