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

export TRAINING_PVC="$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].metadata.name}')"
export CHECKPOINT_PVC="$(kubectl get pvc -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].metadata.name}')"
: "${TRAINING_PVC:?TRAINING_PVC was not found in the cluster}"
: "${CHECKPOINT_PVC:?CHECKPOINT_PVC was not found in the cluster}"

echo "Relaunching Qwen3-30B-A3B JobSet to resume from iter_0000050 through iteration 55 (~20-25 minutes)..."
# [START hypercomputer_gpu_train_qwen_megatron_gke_resume_training]
kubectl delete jobset qwen3-30b-a3b
# [START_EXCLUDE silent]
kubectl wait --for=delete pod -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b --timeout=300s || true
# [END_EXCLUDE]
export TRAIN_ITERS=55
envsubst '${TRAINING_PVC} ${CHECKPOINT_PVC} ${TRAIN_ITERS}' < qwen3-30b-a3b-pretrain-jobset.yaml | kubectl apply -f -
kubectl wait --for=create job/qwen3-30b-a3b-w-0 --timeout=300s
kubectl wait --for=jsonpath='{.status.ready}'=2 job/qwen3-30b-a3b-w-0 --timeout=1200s
# [START_EXCLUDE silent]
LIMIT=240
count=0
while true; do
  if [ "$(kubectl get jobset qwen3-30b-a3b -o jsonpath='{.status.conditions[?(@.type=="Completed")].status}' 2>/dev/null || true)" = "True" ]; then
    break
  fi
  if [ "$(kubectl get jobset qwen3-30b-a3b -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)" = "True" ]; then
    echo "Error: resumed jobset/qwen3-30b-a3b failed." >&2
    kubectl describe jobset qwen3-30b-a3b >&2 || true
    kubectl logs --tail=100 -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b,batch.kubernetes.io/job-completion-index=0 -c megatron-bridge >&2 || true
    kubectl logs --tail=100 -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b,batch.kubernetes.io/job-completion-index=1 -c megatron-bridge >&2 || true
    exit 1
  fi
  if [ "${count}" -ge "${LIMIT}" ]; then
    echo "Error: timeout waiting for resumed jobset/qwen3-30b-a3b to complete." >&2
    kubectl describe jobset qwen3-30b-a3b >&2 || true
    kubectl get pods -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b -o wide >&2 || true
    exit 1
  fi
  sleep 10
  count=$((count + 1))
done
# [END_EXCLUDE]
kubectl wait --for=condition=Completed jobset/qwen3-30b-a3b --timeout=1800s && \
kubectl logs --tail=-1 \
  -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b,batch.kubernetes.io/job-completion-index=1 \
  -c megatron-bridge | grep -E "iteration +(51|52|53|54|55)/" | tail -n 20
# [END hypercomputer_gpu_train_qwen_megatron_gke_resume_training]

echo "Checkpoint resumption through iteration 55 completed."
