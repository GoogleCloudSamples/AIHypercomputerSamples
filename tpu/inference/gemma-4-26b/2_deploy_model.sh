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

# [START hypercomputer_tpu_infer_gemma4_deploy]
echo "Applying LeaderWorkerSet (retrying if webhook is not fully ready)..."
for i in {1..12}; do
  if envsubst '$RESERVATION_URL $ZONE' < vllm-gemma4-26b.yaml | kubectl apply -f -; then
    break
  fi
  echo "Webhook not ready yet, retrying in 5 seconds..."
  sleep 5
done
# [END hypercomputer_tpu_infer_gemma4_deploy]

echo "Deploying the model and tracking progress..."
# [START hypercomputer_tpu_infer_gemma4_deploy_wait]
while ! kubectl get pod -l role=leader | grep -q "vllm-tpu"; do
  echo "Waiting for leader pod to be created..."
  sleep 5
done

# Wait up to 20 minutes for the pod to start running (TPU nodes take a while to boot)
echo "Waiting for pod to be scheduled and running..."
if ! kubectl wait --for=condition=Initialized --timeout=1200s pod -l role=leader; then
  echo "Pod failed to initialize within 20 minutes! Here are the events:"
  kubectl describe pod -l role=leader
  exit 1
fi

echo "Pod is initialized. Streaming logs while waiting for it to become Ready (this includes model download)..."
# Stream logs in the background so the user can see what's happening
kubectl logs -f -l role=leader &
LOG_PID=$!

if ! kubectl wait --for=condition=Ready --timeout=3600s pod -l role=leader; then
  echo "Pod failed to become Ready within 60 minutes!"
  kill $LOG_PID || true
  kubectl describe pod -l role=leader
  exit 1
fi

kill $LOG_PID || true
echo "Pod is Ready!"
# [END hypercomputer_tpu_infer_gemma4_deploy_wait]