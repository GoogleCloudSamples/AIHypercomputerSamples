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

# 1. Create a ConfigMap
# [START hypercomputer_gpu_tune_gemma3_ray_create_configmap]
kubectl create cm ray-job-cm --from-file=code -o yaml --dry-run=client | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_ray_create_configmap]

# 2. Create Ray Cluster
# [START hypercomputer_gpu_tune_gemma3_ray_create_ray_cluster]
envsubst < ray_cluster.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_ray_create_ray_cluster]

# ==============================================================================
#  WAITING FOR THE 'RUNNING' STATE FOR GEMMA3 PODS
# ==============================================================================
echo "Waiting for all gemma3 PODS to transition to the state RUNNING..."

ALL_READY=false

while [ "$ALL_READY" = false ]; do
    #  Retrieve data about the gemma3 pods (Name, Ready, Status)
    PODS_DATA=$(kubectl get pods 2>/dev/null | grep "gemma3" || true)

    if [ -z "$PODS_DATA" ]; then
        echo "Waiting for the pods to start"
        sleep 10
        continue
    fi

    # Extract the READY column (column 2) and the STATUS column (column 3)
    COMPACT_STATUSES=$(echo "$PODS_DATA" | awk '{print $2 ":" $3}')

    # Set the flag to true by default, and then verify each pod
    ALL_READY=true

    for ITEM in $COMPACT_STATUSES; do
        # Split the pair into READY and STATUS
        READY_COUNT=$(echo "$ITEM" | cut -d':' -f1)
        STATUS_NAME=$(echo "$ITEM" | cut -d':' -f2)

        # CONDITION: The pod must have the status "Running" AND the state "2/2"

        if [ "$STATUS_NAME" != "Running" ] || [ "$READY_COUNT" != "2/2" ]; then
            ALL_READY=false
            break
        fi
    done

    if [ "$ALL_READY" = false ]; then
        echo "Awaiting all gemma3 PODS to be ready:"
        # Display the current status
        kubectl get pods | grep -E "NAME|gemma3"
        echo "------------------------------------------------------------------------------"
        sleep 10
    fi
done

echo ""
echo "Success! All PODS are ready and running:"
echo "=============================================================================="
kubectl get pods | grep -E "NAME|gemma3"
echo "=============================================================================="

sleep 20

# 3. Schedule a training job
# [START hypercomputer_gpu_tune_gemma3_ray_training_job]
envsubst < ray_job.yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_ray_training_job]
