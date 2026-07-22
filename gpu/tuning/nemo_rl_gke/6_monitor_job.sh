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

HEAD_POD=$(kubectl get pods -l ray.io/node-type=head -o name)

echo "[$(date)] ========== Inspecting output inside ray-head container =========="

kubectl exec "${HEAD_POD}" -c ray-head -- bash -c "
  set -e
  apt-get update && apt-get install -y tree
  if [ -d '/data/nemo_rl_gemma3_27b_3_17/' ]; then
    # [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_tree]
    tree /data/nemo_rl_gemma3_27b_3_17/
    # [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_tree]
  else
    echo 'Directory /data/nemo_rl_gemma3_27b_3_17/ not found or still being written.'
  fi
"

echo "[$(date)] ========== Monitoring has completed. =========="
