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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR}/gpu-recipes"
export RECIPE_ROOT="${REPO_ROOT}/inference/a4/single-host-serving"

# 1. Check required CLI tools (gcloud, kubectl, helm)
echo "--------------------------------------------------------"
echo "Step 1: Checking Required CLI Tools"
echo "--------------------------------------------------------"

check_gcloud_component() {
    local component=$1
    local binary=$2
    if ! command -v "$binary" &> /dev/null; then
        echo "$binary is not installed. Installing via gcloud..."
        gcloud components install "$component" --quiet
    else
        echo "✓ $binary is already installed. Version:"
        "$binary" version --client 2>/dev/null || "$binary" version
    fi
}

if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI is not installed."
    exit 1
else
    echo "✓ gcloud CLI is installed."
fi

check_gcloud_component "kubectl" "kubectl"

if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "✓ Helm is already installed."
fi

# 2. Enable Google Cloud APIs
echo "--------------------------------------------------------"
echo "Step 2: Enabling Required Google Cloud APIs"
echo "--------------------------------------------------------"
gcloud services enable \
    artifactregistry.googleapis.com \
    container.googleapis.com \
    storage.googleapis.com \
    --project="${PROJECT_ID}"

# 3. Create GCS bucket (if it doesn't exist)
echo "--------------------------------------------------------"
echo "Step 3: Creating Infrastructure Components"
echo "--------------------------------------------------------"

if gcloud storage buckets describe "gs://${GCS_BUCKET}" > /dev/null 2>&1; then
    echo "✓ Bucket gs://${GCS_BUCKET} already exists."
else
    echo "Creating bucket gs://${GCS_BUCKET}..."
    gcloud storage buckets create "gs://${GCS_BUCKET}" \
        --project="${PROJECT_ID}" \
        --location="${REGION}"
fi

# 4. Grant Workload Identity access to GCS bucket
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[default/default]" \
    --role="roles/storage.objectAdmin" \
    --quiet

# 5. Create Artifact Registry repository
REPO_NAME=$(basename "${ARTIFACT_REGISTRY}")

if gcloud artifacts repositories describe "${REPO_NAME}" --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
    echo "✓ Repository '${REPO_NAME}' already exists."
else
    echo "Creating Artifact Registry repository '${REPO_NAME}'..."
    gcloud artifacts repositories create "${REPO_NAME}" \
        --repository-format=docker \
        --location="${REGION}" \
        --project="${PROJECT_ID}" \
        --description="Docker repository for vLLM images"
fi

# 6. Configure Docker authentication
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# 7. Clone or sync GPU recipes repository
echo "--------------------------------------------------------"
echo "Step 4: Synchronizing GPU Recipes Repository"
echo "--------------------------------------------------------"

if [ -d "${REPO_ROOT}/.git" ]; then
    echo "✓ Fetching updates for gpu-recipes..."
    git -C "${REPO_ROOT}" pull --ff-only || echo "Continuing with local version."
else
    echo "Cloning ai-hypercomputer/gpu-recipes..."
    git clone https://github.com/ai-hypercomputer/gpu-recipes.git "${REPO_ROOT}"
fi

echo "✓ Recipe root set to: ${RECIPE_ROOT}"

echo "--------------------------------------------------------"
echo "Setup completed successfully! Environment is ready."
echo "--------------------------------------------------------"
