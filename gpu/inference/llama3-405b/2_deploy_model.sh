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

echo "[$(date)] ==================== Configuring GCS bucket gs://${GCS_BUCKET} for model weights... ===================="
if ! gcloud storage buckets describe "gs://${GCS_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${GCS_BUCKET}" \
      --default-storage-class=STANDARD \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --uniform-bucket-level-access
fi

# [START hypercomputer_gpu_infer_llama3_405b_create_weights_bucket]
GSA=$(kubectl get sa workload-identity-k8s-sa -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}')
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --member="serviceAccount:${GSA}" \
    --role="roles/storage.objectUser"
# [END hypercomputer_gpu_infer_llama3_405b_create_weights_bucket]

echo "[$(date)] ==================== Staging Llama 3.1 405B model weights to gs://${GCS_BUCKET}... ===================="
kubectl delete job llama3-405b-stage-weights --ignore-not-found >/dev/null 2>&1 || true

# [START hypercomputer_gpu_infer_llama3_405b_stage_weights]
envsubst '${GCS_BUCKET}' < llama3.1-405b-stage-weights-job.yaml | kubectl apply -f -

kubectl wait --for=condition=complete job/llama3-405b-stage-weights --timeout=2h
# [END hypercomputer_gpu_infer_llama3_405b_stage_weights]

# [START hypercomputer_gpu_infer_llama3_405b_stage_weights_delete_job]
kubectl delete job llama3-405b-stage-weights
# [END hypercomputer_gpu_infer_llama3_405b_stage_weights_delete_job]

echo "[$(date)] ==================== Deploying Llama 3.1 405B PD-disaggregated server... ===================="
# [START hypercomputer_gpu_infer_llama3_405b_deploy]
envsubst '${GCS_BUCKET}' < llama3.1-405b-singlehost-a4-gcsfuse.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_llama3_405b_deploy]

echo "Waiting for Llama 3.1 405B frontend, prefill, and decode pods to be created..."
timeout=600
elapsed=0
while true; do
  # [START hypercomputer_gpu_infer_llama3_405b_pods_definition]
  frontend_pod=$(kubectl get pods -l "nvidia.com/dynamo-component-type=frontend" -o jsonpath='{.items[*].metadata.name}')
  prefill_pod=$(kubectl get pods -l "nvidia.com/dynamo-sub-component-type=prefill" -o jsonpath='{.items[*].metadata.name}')
  decode_pod=$(kubectl get pods -l "nvidia.com/dynamo-sub-component-type=decode" -o jsonpath='{.items[*].metadata.name}')
  # [END hypercomputer_gpu_infer_llama3_405b_pods_definition]
  if [[ -n "${frontend_pod}" && -n "${prefill_pod}" && -n "${decode_pod}" ]]; then
    break
  fi
  if [[ "${elapsed}" -ge "${timeout}" ]]; then
    echo "Timeout waiting for llama3-405b-a4-disagg pods to be created!" >&2
    kubectl get pods >&2
    exit 1
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

echo "Created pods:"
echo "  Frontend: ${frontend_pod}"
echo "  Prefill:  ${prefill_pod}"
echo "  Decode:   ${decode_pod}"

echo "Waiting for prefill and decode pods to enter Running phase..."
for pod in "${frontend_pod}" "${prefill_pod}" "${decode_pod}"; do
  if ! kubectl wait --for=jsonpath='{.status.phase}'=Running "pod/${pod}" --timeout=1800s; then
    echo "Pod ${pod} failed to enter Running phase within 30 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    exit 1
  fi
done

echo "Streaming decode pod logs while waiting for all pods to become Ready..."
kubectl logs -f "${decode_pod}" &
log_pid=$!

cleanup_logs() {
  kill "${log_pid}" 2>/dev/null || true
}
trap cleanup_logs EXIT

# [START hypercomputer_gpu_infer_llama3_405b_deploy_wait]
for pod in "${frontend_pod}" "${prefill_pod}" "${decode_pod}"; do
  if ! kubectl wait --for=condition=Ready "pod/${pod}" --timeout=3600s; then
    echo "Pod ${pod} failed to become Ready within 60 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    kubectl logs "${pod}" --tail=200 >&2 || true
    exit 1
  fi
done
# [END hypercomputer_gpu_infer_llama3_405b_deploy_wait]

echo "[$(date)] ==================== Llama 3.1 405B deployment is Ready! ===================="
