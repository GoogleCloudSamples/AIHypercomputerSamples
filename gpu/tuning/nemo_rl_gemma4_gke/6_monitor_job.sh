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

HEAD_POD_NAME="$(kubectl get pods -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "${HEAD_POD_NAME}" ]]; then
  echo "Error: No running Ray head pod found." >&2
  exit 1
fi

echo "[$(date)] ========== Inspecting output inside ray-head container =========="

# shellcheck disable=SC2016
kubectl exec "${HEAD_POD_NAME}" -c ray-head -- env RUN_NAME="${RUN_NAME}" bash -c '
  set -e
  if [ ! -d "/data/${RUN_NAME}" ]; then
    echo "Directory /data/${RUN_NAME} not found or still being written."
  elif command -v tree > /dev/null; then
    # [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_tree]
    tree -L 3 "/data/${RUN_NAME}"
    # [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_tree]
  else
    find "/data/${RUN_NAME}" -maxdepth 3
  fi
'

echo "[$(date)] ========== Monitoring has completed. =========="
