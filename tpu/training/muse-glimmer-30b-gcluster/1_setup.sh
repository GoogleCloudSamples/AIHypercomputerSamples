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

echo "[$(date)] ==================== Checking local tools... ===================="
for tool in gcloud kubectl gke-gcloud-auth-plugin git curl tar; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Error: required tool '${tool}' is not installed or not in PATH." >&2
    exit 1
  fi
done

echo "[$(date)] ==================== Installing Cluster Toolkit ${CTK_VERSION:?}... ===================="
# Download the prebuilt Cluster Toolkit bundle into the sample directory
curl -fsSL -O "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/v${CTK_VERSION}/gcluster_bundle_linux_amd64.tgz"
tar -xzf gcluster_bundle_linux_amd64.tgz
./gcluster --version

echo "[$(date)] ==================== Cluster Toolkit is installed. ===================="
