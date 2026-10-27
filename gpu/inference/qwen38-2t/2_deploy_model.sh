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

# [START hypercomputer_gpu_infer_qwen38_2t_create_weights_bucket]
GSA=$(kubectl get sa workload-identity-k8s-sa -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}')
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --member="serviceAccount:${GSA}" \
    --role="roles/storage.objectUser"
# [END hypercomputer_gpu_infer_qwen38_2t_create_weights_bucket]

echo "[$(date)] ==================== Staging Qwen 3.8 2.4T model weights to gs://${GCS_BUCKET}... ===================="
kubectl delete job qwen3-8-2-4t-stage-weights --ignore-not-found >/dev/null 2>&1 || true

# [START hypercomputer_gpu_infer_qwen38_2t_stage_weights]
sed "s|<BUCKET_NAME>|${GCS_BUCKET}|g" qwen3.8-2.4t-nvfp4-stage-weights-job.yaml | kubectl apply -f -

kubectl wait --for=condition=complete job/qwen3-8-2-4t-stage-weights --timeout=2h

kubectl delete job qwen3-8-2-4t-stage-weights
# [END hypercomputer_gpu_infer_qwen38_2t_stage_weights]

echo "[$(date)] ==================== Deploying Qwen 3.8 2.4T multihost PD-disaggregated server... ===================="
# [START hypercomputer_gpu_infer_qwen38_2t_deploy]
sed "s|<BUCKET_NAME>|${GCS_BUCKET}|g" qwen3.8-2.4t-nvfp4-multihost-a4-gcsfuse.yaml | kubectl apply -f -
# [END hypercomputer_gpu_infer_qwen38_2t_deploy]

echo "Waiting for Qwen 3.8 2.4T frontend, prefill, and decode pods to be created..."
timeout=600
elapsed=0
while true; do
  pods=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "^qwen3-8-2-4t-a4-disagg" || true)
  if echo "${pods}" | grep -q "frontend" && echo "${pods}" | grep -q "prefill-ldr" && echo "${pods}" | grep -q "decode-ldr"; then
    break
  fi
  if [[ "${elapsed}" -ge "${timeout}" ]]; then
    echo "Timeout waiting for qwen3-8-2-4t-a4-disagg pods to be created!" >&2
    kubectl get pods >&2
    exit 1
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

# [START hypercomputer_gpu_infer_qwen38_2t_pods_definition]
frontend_pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*frontend" | head -n 1)
prefill_ldr_pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*prefill-ldr" | head -n 1)
decode_ldr_pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg.*decode-ldr" | head -n 1)
# [END hypercomputer_gpu_infer_qwen38_2t_pods_definition]

echo "Created leader/frontend pods:"
echo "  Frontend:    ${frontend_pod}"
echo "  Prefill Ldr: ${prefill_ldr_pod}"
echo "  Decode Ldr:  ${decode_ldr_pod}"

echo "Waiting for pods to enter Running phase..."
for pod in $(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^qwen3-8-2-4t-a4-disagg"); do
  if ! kubectl wait --for=jsonpath='{.status.phase}'=Running "pod/${pod}" --timeout=1800s; then
    echo "Pod ${pod} failed to enter Running phase within 30 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    exit 1
  fi
done

echo "Streaming decode-ldr pod logs while waiting for pods to become Ready..."
kubectl logs -f "${decode_ldr_pod}" &
log_pid=$!

cleanup_logs() {
  kill "${log_pid}" 2>/dev/null || true
}
trap cleanup_logs EXIT

# [START hypercomputer_gpu_infer_qwen38_2t_deploy_wait]
for pod in "${frontend_pod}" "${prefill_ldr_pod}" "${decode_ldr_pod}"; do
  if ! kubectl wait --for=condition=Ready "pod/${pod}" --timeout=7200s; then
    echo "Pod ${pod} failed to become Ready within 120 minutes!" >&2
    kubectl describe "pod/${pod}" >&2
    kubectl logs "${pod}" --tail=200 >&2 || true
    exit 1
  fi
done
# [END hypercomputer_gpu_infer_qwen38_2t_deploy_wait]

echo "[$(date)] ==================== Qwen 3.8 2.4T deployment is Ready! ===================="
