#!/bin/bash

set -euo pipefail

source 0_env.sh

echo "Applying Ray Cluster..."
envsubst < "ray-cluster-auto-dranet.yaml" | kubectl apply -f -

echo "Workload deployment initiated."
