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

echo "[$(date)] ==================== Installing Prerequisites ===================="

# [START hypercomputer_tpu_tune_gemma4_26b_rl_install_dependencies_v2]
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              BUNDLE="gcluster_bundle_linux_amd64.tgz" ;;
  Linux-aarch64|Linux-arm64) BUNDLE="gcluster_bundle_linux_arm64.tgz" ;;
  Darwin-x86_64)             BUNDLE="gcluster_bundle_mac_amd64.tgz" ;;
  Darwin-arm64)              BUNDLE="gcluster_bundle_mac_arm64.tgz" ;;
  *) BUNDLE=""; echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2 ;;
esac
mkdir -p cluster-toolkit
curl -fsSL "https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${CLUSTER_TOOLKIT_VERSION:?}/${BUNDLE:?}" \
  | tar -xz -C cluster-toolkit
cd cluster-toolkit
# [END hypercomputer_tpu_tune_gemma4_26b_rl_install_dependencies_v2]
cp -r gcluster examples community ..
echo "[$(date)] ==================== Prerequisites Installed ===================="
