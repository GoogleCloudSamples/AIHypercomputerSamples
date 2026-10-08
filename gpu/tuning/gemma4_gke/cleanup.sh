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

kubectl delete job finetune-job --ignore-not-found=true || true
echo "[$(date)] ==================== Job deleted. ===================="

gcloud container clusters delete "${CLUSTER_NAME}" \
    --region="${CLUSTER_REGION}" --quiet || true
echo "[$(date)] ==================== Cluster deleted. ===================="

gcloud artifacts repositories delete gemma \
    --location="${ARTIFACT_REPO_LOCATION}" \
    --quiet || true
echo "[$(date)] ==================== Artifact Registry deleted. ===================="

HF_USERNAME="$(curl -sSf -H "Authorization: Bearer ${HF_TOKEN}" \
    https://huggingface.co/api/whoami-v2 \
    | python3 -c "import json, sys; print(json.load(sys.stdin)['name'])" \
    2>/dev/null)" || true
if [[ -n "${HF_USERNAME:-}" ]] && curl -sSf -o /dev/null -X DELETE \
    https://huggingface.co/api/repos/delete \
    -H "Authorization: Bearer ${HF_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"type\": \"model\", \"name\": \"gemma-31b-text-to-sql\",
         \"organization\": \"${HF_USERNAME}\"}"; then
    echo "[$(date)] ==================== Hugging Face model repo deleted. ===================="
else
    echo "[$(date)] WARNING: could not delete Hugging Face model repo" \
        "gemma-31b-text-to-sql (already deleted or invalid HF_TOKEN)."
fi
