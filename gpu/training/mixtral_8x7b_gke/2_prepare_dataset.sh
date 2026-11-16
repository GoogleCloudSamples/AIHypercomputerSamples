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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "Retrieving Cloud Storage FUSE PersistentVolumeClaims..."
# [START hypercomputer_gpu_train_mixtral_8x7b_get_pvcs]
export TRAINING_PVC="$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].metadata.name}')"
export CHECKPOINT_PVC="$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].metadata.name}')"
echo "Training PVC:   ${TRAINING_PVC}"
echo "Checkpoint PVC: ${CHECKPOINT_PVC}"
# [END hypercomputer_gpu_train_mixtral_8x7b_get_pvcs]

echo "Submitting the C4 dataset preparation Job..."
# [START hypercomputer_gpu_train_mixtral_8x7b_submit_data_prep]
sed "s|\${TRAINING_PVC}|${TRAINING_PVC}|g" mixtral-data-prep.yaml | kubectl apply -f -
# [END hypercomputer_gpu_train_mixtral_8x7b_submit_data_prep]

echo "Waiting for the dataset preparation Job to run and complete..."
# [START hypercomputer_gpu_train_mixtral_8x7b_wait_data_prep]
sleep 5
kubectl wait --for=condition=Ready pod -l job-name=mixtral-data-prep --timeout=1200s
kubectl logs -f job/mixtral-data-prep -c data-prep
kubectl wait --for=condition=complete job/mixtral-data-prep --timeout=600s
# [END hypercomputer_gpu_train_mixtral_8x7b_wait_data_prep]

echo "Tokenized C4 dataset is staged in Cloud Storage."
