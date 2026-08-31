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

echo "Deploying RayCluster..."

# [START hypercomputer_gpu_train_ray_verl_std_deploy_ray]
envsubst < "ray-cluster-standard.yaml" | kubectl apply -f -
# [END hypercomputer_gpu_train_ray_verl_std_deploy_ray]

echo "Workload deployment initiated."

echo "Waiting for Ray GPU worker pods to be created by KubeRay Operator..."
MAX_RETRIES=60
RETRY_COUNT=0

# An implementation of a loop that waits until at least one worker pod appears in the K8s API
until kubectl get pods -n ${NAMESPACE} -l ray.io/node-type=worker 2>/dev/null | grep -qE "b200|ray|Running|Pending"; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: Timeout waiting for Ray GPU worker pods to be created by Operator."
    kubectl get rayclusters -n ${NAMESPACE}
    exit 1
  fi
  echo "Pods not created yet, waiting 5s ($RETRY_COUNT/$MAX_RETRIES)..."
  sleep 5
done

WORKER_TIMEOUT="${WORKER_TIMEOUT:-1200s}"
WORKER_LABELS="ray.io/node-type=worker"
echo "Ray GPU worker pods detected! Waiting up to ${WORKER_TIMEOUT} for Ready status..."
if ! kubectl wait --for=condition=ready pod \
  -l "${WORKER_LABELS}" \
  -n "${NAMESPACE}" \
  --timeout="${WORKER_TIMEOUT}"; then
  echo "Error: Ray GPU worker pods failed to become ready within timeout."
  echo "Describing Ray GPU worker pods:"
  kubectl describe pods \
    -l "${WORKER_LABELS}" \
    -n "${NAMESPACE}" || true
  echo "Fetching events sorted by creation timestamp:"
  kubectl get events -n "${NAMESPACE}" --sort-by='.metadata.creationTimestamp' || true
  exit 1
fi
