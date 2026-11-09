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

RAY_CLUSTER_NAME="gemma4-tuning"

# 1. Create a ConfigMap
# [START hypercomputer_gpu_tune_gemma4_ray_create_configmap]
kubectl create configmap gemma4-tuning-code --from-file=code \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_ray_create_configmap]

echo "Waiting for the Ray operator to accept the RayCluster manifest..."
MAX_ATTEMPTS=40
RETRY_DELAY=15
ATTEMPT=1
until envsubst < ray_cluster.yaml | kubectl apply --dry-run=server -f - > /dev/null; do
    if [[ "${ATTEMPT}" -ge "${MAX_ATTEMPTS}" ]]; then
        echo "Error: The Ray operator did not accept ray_cluster.yaml after ${MAX_ATTEMPTS} attempts."
        kubectl get crd | grep -E "NAME|ray.io" || true
        kubectl get pods -A | grep -iE "NAME|ray" || true
        exit 1
    fi
    echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS} failed. Retrying in ${RETRY_DELAY}s..."
    sleep "${RETRY_DELAY}"
    ATTEMPT=$((ATTEMPT + 1))
done

# 2. Create Ray Cluster
# [START hypercomputer_gpu_tune_gemma4_ray_create_ray_cluster]
envsubst < ray_cluster.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_ray_create_ray_cluster]

WORKER_REPLICAS="$(kubectl get raycluster "${RAY_CLUSTER_NAME}" \
    -o jsonpath='{.spec.workerGroupSpecs[0].replicas}')"
EXPECTED_PODS=$((WORKER_REPLICAS + 1))
echo "Waiting for ${EXPECTED_PODS} Ray pods (1 head, ${WORKER_REPLICAS} workers) to be ready..."

TIMEOUT_SECONDS=1800
INTERVAL_SECONDS=15
ELAPSED_SECONDS=0
while true; do
    READY_PODS="$(kubectl get pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" \
        -o jsonpath='{range .items[*]}{.status.phase}{" "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
        | grep -c "^Running True$" || true)"
    if [[ "${READY_PODS}" -ge "${EXPECTED_PODS}" ]]; then
        break
    fi
    if [[ "${ELAPSED_SECONDS}" -ge "${TIMEOUT_SECONDS}" ]]; then
        echo "Error: Ray pods were not ready within ${TIMEOUT_SECONDS}s."
        kubectl get pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" -o wide || true
        kubectl describe pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" | tail -n 60 || true
        kubectl get events --sort-by='.metadata.creationTimestamp' | tail -n 30 || true
        exit 1
    fi
    echo "${READY_PODS}/${EXPECTED_PODS} Ray pods ready (${ELAPSED_SECONDS}/${TIMEOUT_SECONDS}s elapsed)..."
    sleep "${INTERVAL_SECONDS}"
    ELAPSED_SECONDS=$((ELAPSED_SECONDS + INTERVAL_SECONDS))
done

echo "All Ray pods are ready:"
kubectl get pods -l "ray.io/cluster=${RAY_CLUSTER_NAME}" -o wide

sleep 20

# 3. Schedule a training job
# [START hypercomputer_gpu_tune_gemma4_ray_training_job]
envsubst < ray_job.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma4_ray_training_job]
