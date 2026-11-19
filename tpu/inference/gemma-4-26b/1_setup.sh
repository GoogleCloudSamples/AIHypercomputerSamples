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

# [START hypercomputer_tpu_infer_gemma4_26b_cluster_create]
gcloud container clusters create "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --machine-type=e2-standard-4

gcloud container node-pools create "${NODE_POOL_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --cluster="${CLUSTER_NAME}" \
    --node-locations="${ZONE}" \
    --machine-type=ct6e-standard-4t \
    --tpu-topology=2x4 \
    --num-nodes=2 \
    --disk-size=500 \
    --reservation-affinity=specific \
    --reservation="${RESERVATION_NAME}"
# [END hypercomputer_tpu_infer_gemma4_26b_cluster_create]

echo "Verifying cluster status..."
STATUS=$(gcloud container clusters describe "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --format="value(status)")

if [ "${STATUS}" = "RUNNING" ]; then
    echo "Success! Cluster ${CLUSTER_NAME} is RUNNING and ready for deployment."
else
    echo "Error: Cluster is in '${STATUS}' state." >&2
    exit 1
fi

# [START hypercomputer_tpu_infer_gemma4_26b_cluster_get_creds]
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_tpu_infer_gemma4_26b_cluster_get_creds]

# [START hypercomputer_tpu_infer_gemma4_26b_secret_create]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_tpu_infer_gemma4_26b_secret_create]

echo "Installing LeaderWorkerSet controller..."
# [START hypercomputer_tpu_infer_gemma4_26b_lws_install]
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/v1.0.0/manifests.yaml
echo "Waiting for LWS controller to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/lws-controller-manager -n lws-system
# [END hypercomputer_tpu_infer_gemma4_26b_lws_install]

echo "Waiting for Konnectivity agent and LWS webhook to be ready..."
kubectl wait --for=condition=Available --timeout=300s \
  deployment/konnectivity-agent -n kube-system
kubectl wait --for=jsonpath='{.webhooks[0].clientConfig.caBundle}' --timeout=300s \
  validatingwebhookconfiguration/lws-validating-webhook-configuration
kubectl wait --for=jsonpath='{.webhooks[0].clientConfig.caBundle}' --timeout=300s \
  mutatingwebhookconfiguration/lws-mutating-webhook-configuration

# The LWS controller runs multiple replicas. Each replica starts serving the
# webhook on :9443 only after kubelet projects the cert Secret into its pod,
# which can happen several seconds apart. Wait until every replica is serving,
# otherwise the API server may route webhook calls to a replica that is not
# listening yet ("connect: connection refused").
echo "Waiting for all LWS controller replicas to serve the webhook on :9443..."
LWS_WEBHOOK_READY=false
for attempt in $(seq 1 60); do
  DESIRED=$(kubectl get deployment lws-controller-manager -n lws-system \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)
  PODS=$(kubectl get pods -n lws-system -l control-plane=controller-manager \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

  TOTAL=0
  SERVING=0
  for pod in ${PODS}; do
    TOTAL=$((TOTAL + 1))
    if kubectl logs -n lws-system "${pod}" 2>/dev/null | grep -q "Serving webhook server"; then
      SERVING=$((SERVING + 1))
    fi
  done

  if [ "${TOTAL}" -gt 0 ] && [ "${TOTAL}" -ge "${DESIRED:-1}" ] && [ "${SERVING}" -eq "${TOTAL}" ]; then
    echo "All ${TOTAL} LWS controller replica(s) are serving the webhook."
    LWS_WEBHOOK_READY=true
    break
  fi
  echo "  ${SERVING}/${TOTAL} replica(s) serving (desired: ${DESIRED:-?}), attempt ${attempt}/60..."
  sleep 5
done

if [ "${LWS_WEBHOOK_READY}" != "true" ]; then
  echo "Error: timed out waiting for all LWS webhook replicas to serve on :9443." >&2
  exit 1
fi
