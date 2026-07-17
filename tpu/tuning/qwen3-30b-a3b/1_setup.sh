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

#!/bin/bash

set -euo pipefail

echo "[$(date)] ==================== Starting setup for Qwen3-30b-a3b model using MaxText ===================="

# 1. Create Google Cloud Storage Bucket (if it doesn't exist)
echo "Checking if bucket gs://$GCS_BUCKET already exists..."

if gcloud storage buckets describe "gs://$GCS_BUCKET" > /dev/null 2>&1; then
    echo "Bucket gs://$GCS_BUCKET already exists. Skipping creation."
else
    echo "Bucket does not exist. Creating bucket gs://$GCS_BUCKET..."
      gcloud storage buckets create "gs://${GCS_BUCKET}" \
        --project="${PROJECT_ID}"
fi

# 2. Create Artifact Registry repository (if it doesn't exist)
echo "Checking Artifact Registry repository..."
if gcloud artifacts repositories describe maxtext-images --location="${REGION}" --project="${PROJECT}" &>/dev/null; then
    echo "Repository 'maxtext-images' already exists. Skipping creation."
else
    echo "Repository 'maxtext-images' does not exist. Creating it now..."
    gcloud artifacts repositories create maxtext-images \
        --repository-format=docker \
        --location="${REGION}" \
        --project="${PROJECT}" \
        --description="Docker repository for MaxText images in ${REGION}"
    echo "Repository created successfully."
fi

# 3. Create temporary build VM
echo "Checking if temporary build VM ${VM_NAME} already exists..."
if gcloud compute instances describe "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT}" &>/dev/null; then
    echo "VM ${VM_NAME} already exists from a previous run. Deleting it to ensure a clean build environment..."
    gcloud compute instances delete "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT}" --quiet
    echo "Previous VM deleted successfully."
fi

echo "Creating temporary build virtual machine: ${VM_NAME}..."
gcloud compute instances create "${VM_NAME}" \
  --zone "${ZONE}" \
  --project "${PROJECT}" \
  --machine-type "${BUILDER_MACHINE_TYPE:-n4-standard-16}" \
  --scopes=cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name="${VM_NAME}",image-family="${BUILD_IMAGE_FAMILY:-ubuntu-2404-lts-amd64}",image-project="${BUILD_IMAGE_PROJECT:-ubuntu-os-cloud}",mode=rw,size="${BUILD_DISK_SIZE:-200}",type="${BUILD_DISK_TYPE:-hyperdisk-balanced}"

# Dynamic detection of the VPC network and configuration of the IAP Firewall
echo "Identifying VPC Network and ensuring IAP firewall rule exists..."

VPC_NETWORK_URI=$(gcloud compute instances describe "${VM_NAME}" \
  --project="${PROJECT}" \
  --zone="${ZONE}" \
  --format="value(networkInterfaces[0].network)" 2>/dev/null || echo "")

CLUSTER_NETWORK=$(basename "${VPC_NETWORK_URI}")

if [ -z "${CLUSTER_NETWORK}" ]; then
  echo "Error: Could not determine VPC network for instance ${VM_NAME}." >&2
  exit 1
fi
echo "Detected VPC Network: ${CLUSTER_NETWORK}"

FIREWALL_RULE_NAME="allow-ssh-from-iap-${CLUSTER_NETWORK}"

FIREWALL_EXISTS=$(gcloud compute firewall-rules list \
  --project="${PROJECT}" \
  --filter="name=${FIREWALL_RULE_NAME} AND network=${CLUSTER_NETWORK}" \
  --format="value(name)" 2>/dev/null || echo "")

if [ -z "${FIREWALL_EXISTS}" ]; then
  echo "Creating missing firewall rule '${FIREWALL_RULE_NAME}' for network ${CLUSTER_NETWORK}..."
  gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT}" \
    --network="${CLUSTER_NETWORK}" \
    --direction=INGRESS \
    --action=allow \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP) for ${CLUSTER_NETWORK}"
  echo "Firewall rule created successfully."
else
  echo "Firewall rule '${FIREWALL_RULE_NAME}' already exists for this network. Skipping creation."
fi
# -----------------------------------------------------------------

echo "Waiting for SSH services to become ready on ${VM_NAME}..."
BOOT_TIMEOUT=120
ELAPSED=0
until gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --quiet \
  --command "echo 'SSH is up'" &>/dev/null || [ $ELAPSED -eq $BOOT_TIMEOUT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "Still waiting for VM to boot... (${ELAPSED}s/${BOOT_TIMEOUT}s)"
done

if [ $ELAPSED -ge $BOOT_TIMEOUT ]; then
    echo "Error: VM SSH service did not become ready within ${BOOT_TIMEOUT} seconds." >&2
    exit 1
fi

echo "VM is fully booted and accepting connections. Proceeding to image build..."

# 4. Build the MaxText container image inside the VM (using IAP tunnel)
echo "Running the image build procedure inside ${VM_NAME} via IAP tunnel..."

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT}" \
  --zone "${ZONE}" \
  --quiet \
  --tunnel-through-iap \
  --command "
set -eux

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo groupadd docker || true
sudo usermod -aG docker \$USER

# Set up Python environment and uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source \$HOME/.local/bin/env

uv venv --python 3.12 --seed maxtext_venv
source maxtext_venv/bin/activate
uv pip install maxtext[runner]==0.2.1 --resolution=lowest

# Build MaxText image
echo 'Starting MaxText Docker image build (this takes around 10 minutes)...'
sg docker -c 'build_maxtext_docker_image WORKFLOW=post-training'

# Tag and push the image to Artifact Registry (Executing ALL docker-related commands within sg context)
echo 'Authenticating and pushing image to Artifact Registry...'
sg docker -c \"
  gcloud auth configure-docker --quiet ${REGION}-docker.pkg.dev && \
  docker tag maxtext_base_image ${CLOUD_IMAGE_NAME} && \
  docker push ${CLOUD_IMAGE_NAME}
\"

echo 'Image successfully pushed to Artifact Registry.'
"

# 5. Clean up the build VM
echo "Deleting temporary build VM: ${VM_NAME}..."
gcloud compute instances delete "${VM_NAME}" --project "${PROJECT}" --zone "${ZONE}" --quiet

echo "Setup completed successfully. Bucket is ready and the MaxText image is in your Artifact Registry."
