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
# [START hypercomputer_tpu_tune_gemma4_26b_rl_install_dependencies]
wget -qO- https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/v1.102.0/gcluster_bundle_linux_amd64.tgz | tar -xz
# [END hypercomputer_tpu_tune_gemma4_26b_rl_install_dependencies]
echo "[$(date)] ==================== Prerequisites Installed ===================="