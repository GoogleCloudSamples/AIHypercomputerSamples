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

if [ -d "venvp3" ]; then
  source venvp3/bin/activate
fi

echo "[$(date)] ==================== Cleaning up resources... ===================="
# [START hypercomputer_tpu_tune_qwen3_sft_cleanup]
echo "Waiting for background cluster operations (like autoscaling) to finish..."
while gcloud container operations list --project=$PROJECT --location=$REGION --filter="status=RUNNING AND targetLink:$CLUSTER_NAME" --format="value(name)" | grep -q .; do
  sleep 30
done
xpk cluster delete --cluster $CLUSTER_NAME --project $PROJECT --zone $ZONE --force
gcloud storage rm --recursive gs://$GCS_BUCKET

gcloud artifacts repositories delete maxtext-images --location=$REGION --project=$PROJECT --quiet
# [END hypercomputer_tpu_tune_qwen3_sft_cleanup]
echo "[$(date)] ==================== Resources cleaned up. ===================="
