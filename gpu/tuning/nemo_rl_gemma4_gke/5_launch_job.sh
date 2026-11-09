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
TARGET_DIR="${SCRIPT_DIR}/kubernetes-engine-samples"
cd "${TARGET_DIR}/ai-ml/nemo-rl-on-gke/nemoRL/gemma3-27b-it"

echo "[$(date)] ========== Launching Ray session =========="
kubectl ray session ray-cluster-kuberay >/dev/null 2>&1 &
RAY_SESSION_PID=$!

echo "[$(date)] ========== Verifying Ray session status =========="
if ! kill -0 "$RAY_SESSION_PID" 2>/dev/null; then
  echo "Error: Ray session failed to start." >&2
  exit 1
else
  echo "Ray session is launched."
fi

echo "[$(date)] ========== Replacing values in gemma3-27b-gsm8k.sh file =========="
sed -i "s|WANDB_API_KEY='YOUR_WANDB_API_KEY'|WANDB_API_KEY='${WANDB_API_KEY}'|" gemma3-27b-gsm8k.sh
sed -i "s|HF_TOKEN='YOUR_HF_TOKEN'|HF_TOKEN='${HF_TOKEN}'|" gemma3-27b-gsm8k.sh

echo "[$(date)] ========== Submitting the Job =========="
bash gemma3-27b-gsm8k.sh 2>&1 | tee logs/job_output.log
