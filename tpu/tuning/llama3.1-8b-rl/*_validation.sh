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

echo "== [Validation] Starting validation for Llama 3.1 8B RL sample =="

# 1. Verify the TPU VM is responsive and check if the final Hugging Face output folder exists and contains files.
echo "Checking final exported Hugging Face weights on TPU VM..."
gcloud compute tpus tpu-vm ssh "$TPU_NAME" \
    --zone "$ZONE" \
    --project "$PROJECT" \
    --command="ls -lh /dev/shm/llama3.1-8b-Instruct/hf-trained/"

# 2. Check if the actor checkpoint parameter directory exists and is populated
echo "Verifying actor checkpoint directory on TPU VM..."
gcloud compute tpus tpu-vm ssh "$TPU_NAME" \
    --zone "$ZONE" \
    --project "$PROJECT" \
    --command="ls -lh /dev/shm/llama3.1-8b-Instruct/post-train/*/checkpoints/actor/50/model_params"

echo "== [Validation] SUCCESS: All artifacts successfully generated on the TPU VM =="
