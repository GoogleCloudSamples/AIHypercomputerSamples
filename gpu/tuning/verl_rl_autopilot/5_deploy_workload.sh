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
set -x

echo "Applying Ray Cluster..."
# [START hypercomputer_gpu_train_ray_verl_auto_deploy_ray]
envsubst < "ray-cluster-auto-dranet.yaml" | kubectl apply -n "${NAMESPACE}" -f -
# [END hypercomputer_gpu_train_ray_verl_auto_deploy_ray]

echo "Debug: RayCluster resource status:"
kubectl get raycluster -n "${NAMESPACE}" || true

echo "Waiting for Ray GPU worker pods to be created..."
WORKER_LABELS="ray.io/node-type=worker,ray.io/cluster=b200-ray-cluster-dranet"
TIMEOUT=300
ELAPSED=0
until [ -n "$(kubectl get pods -l "${WORKER_LABELS}" -n "${NAMESPACE}" --no-headers 2>/dev/null)" ]; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Error: Timeout waiting for Ray GPU worker pods to be created."
    exit 1
  fi
  echo "Debug: Current pods in namespace ${NAMESPACE}:"
  kubectl get pods -n "${NAMESPACE}" || true
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

WORKER_TIMEOUT="${WORKER_TIMEOUT:-1320s}"
echo "Waiting up to ${WORKER_TIMEOUT} for Ray GPU worker pods to become Ready..."
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

