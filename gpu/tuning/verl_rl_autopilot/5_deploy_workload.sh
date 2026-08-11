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
envsubst < "ray-cluster-auto-dranet.yaml" | kubectl apply -f -
# [END hypercomputer_gpu_train_ray_verl_auto_deploy_ray]

echo "Debug: RayCluster resource status:"
kubectl get raycluster -n "${NAMESPACE}" || true

echo "Waiting for Ray GPU worker pods to be created..."
until [ -n "$(kubectl get pods -l "ray.io/node-type=worker,ray.io/cluster=b200-ray-cluster-dranet" -n "${NAMESPACE}" --no-headers 2>/dev/null)" ]; do
  echo "Debug: Current pods in namespace ${NAMESPACE}:"
  kubectl get pods -n "${NAMESPACE}" || true
  sleep 5
done

echo "Waiting for Ray GPU worker pods to become Ready..."
kubectl wait --for=condition=ready pod \
  -l "ray.io/node-type=worker,ray.io/cluster=b200-ray-cluster-dranet" \
  -n "${NAMESPACE}" \
  --timeout=1200s
