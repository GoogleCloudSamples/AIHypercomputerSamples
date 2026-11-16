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

export TRAINING_PVC="${TRAINING_PVC:-$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].metadata.name}')}"
export CHECKPOINT_PVC="${CHECKPOINT_PVC:-$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].metadata.name}')}"

echo "Submitting the Mixtral 8x7B Megatron-LM pre-training JobSet..."
# [START hypercomputer_gpu_train_mixtral_8x7b_submit_jobset]
sed \
  -e "s|\${TRAINING_PVC}|${TRAINING_PVC}|g" \
  -e "s|\${CHECKPOINT_PVC}|${CHECKPOINT_PVC}|g" \
  mixtral-8x7b-pretrain-jobset.yaml | kubectl apply -f -
# [END hypercomputer_gpu_train_mixtral_8x7b_submit_jobset]

echo "Waiting for both Mixtral 8x7B worker Pods to become Ready..."
# [START hypercomputer_gpu_train_mixtral_8x7b_wait_pods]
sleep 5
kubectl get workloads,jobset,pods -o wide
kubectl wait --for=condition=Ready pod -l jobset.sigs.k8s.io/jobset-name=mixtral-8x7b,batch.kubernetes.io/job-completion-index=0 --timeout=1200s
kubectl wait --for=condition=Ready pod -l jobset.sigs.k8s.io/jobset-name=mixtral-8x7b,batch.kubernetes.io/job-completion-index=1 --timeout=1200s
# [END hypercomputer_gpu_train_mixtral_8x7b_wait_pods]

echo "Both Mixtral 8x7B worker Pods are Running."
