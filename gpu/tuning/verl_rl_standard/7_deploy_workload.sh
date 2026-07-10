#!/bin/bash

set -euo pipefail

source 0_env.sh

echo "Deploying RayCluster..."

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsubst < "${SCRIPT_DIR}/ray-cluster-standard.yaml" | kubectl apply -f -

echo "Workload deployment initiated."
