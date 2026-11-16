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

# [START hypercomputer_gpu_train_mixtral_8x7b_workload_cleanup]
export TRAINING_BUCKET="${TRAINING_BUCKET:-$(kubectl get pv -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].spec.csi.volumeHandle}' 2>/dev/null || true)}"
export CHECKPOINT_BUCKET="${CHECKPOINT_BUCKET:-$(kubectl get pv -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].spec.csi.volumeHandle}' 2>/dev/null || true)}"

kubectl delete jobset mixtral-8x7b --ignore-not-found
kubectl delete job mixtral-data-prep --ignore-not-found
kubectl delete jobset -l kueue.x-k8s.io/queue-name=a4 --ignore-not-found

if [[ -n "${TRAINING_BUCKET}" ]]; then
  gcloud storage rm --recursive "gs://${TRAINING_BUCKET}/dataset" "gs://${TRAINING_BUCKET}/tokenizer" 2>/dev/null || true
fi
if [[ -n "${CHECKPOINT_BUCKET}" ]]; then
  gcloud storage rm --recursive "gs://${CHECKPOINT_BUCKET}/mixtral-8x7b" "gs://${CHECKPOINT_BUCKET}/data-cache" 2>/dev/null || true
fi
# [END hypercomputer_gpu_train_mixtral_8x7b_workload_cleanup]

if [[ -d cluster-toolkit && ! -x ./gcluster ]]; then
  cd cluster-toolkit
fi

# [START hypercomputer_gpu_train_mixtral_8x7b_cluster_cleanup]
./gcluster destroy "${CLUSTER_NAME}" --robust --auto-approve
# [END hypercomputer_gpu_train_mixtral_8x7b_cluster_cleanup]

# [START hypercomputer_gpu_train_mixtral_8x7b_tf_bucket_cleanup]
gcloud storage rm --recursive "gs://${BUCKET_NAME}"
# [END hypercomputer_gpu_train_mixtral_8x7b_tf_bucket_cleanup]

# [START hypercomputer_gpu_train_mixtral_8x7b_verify_cleanup]
gcloud container clusters list --project="${PROJECT_ID}" --filter="name=${CLUSTER_NAME}"
BASE_RESERVATION_NAME="$(cut -d/ -f1 <<< "${RESERVATION_NAME}")"
gcloud compute reservations describe "${BASE_RESERVATION_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="table(name,zone.basename(),status,specificReservation.count,specificReservation.inUseCount)"
# [END hypercomputer_gpu_train_mixtral_8x7b_verify_cleanup]
