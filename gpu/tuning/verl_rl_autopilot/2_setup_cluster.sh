#!/bin/bash

set -euo pipefail

source 0_env.sh

# Create an Autopilot cluster on Rapid channel (required for DRANET in some versions)
# We also enable-ray-operator as in the original script.
echo "Creating Autopilot cluster ${CLUSTER_NAME}..."
gcloud container clusters create-auto ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --release-channel=rapid \
    --enable-ray-operator

# Get credentials for your cluster:
gcloud container clusters get-credentials ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION}

echo "Autopilot cluster ${CLUSTER_NAME} created and credentials configured."
