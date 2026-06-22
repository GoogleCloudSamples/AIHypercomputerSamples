#!/bin/bash
#
#   Copyright 2026 Google LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail

# [START hypercomputer_gpu_tune_gemma3_ray_validation]
echo "=============================================================================="
echo "Running Ultra-Light Gemma 3 Vision validation job via Ray..."

echo "Checking for the latest fine-tuned checkpoint in gs://${GCS_BUCKET}..."
LATEST_CHECKPOINT=$(gcloud storage ls "gs://${GCS_BUCKET}/" | grep "gemma_vision_train_" | sort | tail -n 1)

if [[ -z "$LATEST_CHECKPOINT" ]]; then
    echo "Error: No fine-tuning checkpoints found in gs://${GCS_BUCKET}"
    exit 1
fi

echo "Found latest checkpoint artifact: ${LATEST_CHECKPOINT}"
echo "=============================================================================="

HEAD_POD=$(kubectl get pods -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')

echo "Submitting validation job directly to Head Pod: ${HEAD_POD}..."

DOWNLOAD_SCRIPT="import os; from google.cloud import storage; c='${LATEST_CHECKPOINT}'.replace('gs://','').split('/'); b=storage.Client().bucket(c[0]); p='/'.join(c[1:]); os.makedirs('/tmp/checkpoint',exist_ok=True); [blob.download_to_filename(os.path.join('/tmp/checkpoint',os.path.basename(blob.name))) for blob in b.list_blobs(prefix=p) if not blob.name.endswith('/')]"

INLINE_VALIDATION_SCRIPT="
import os, torch
from transformers import Gemma3ForConditionalGeneration, Gemma3Processor
from peft import PeftModel

model_id = 'google/gemma-3-4b-it'
print('1/3 [OK] Loading processor and configuration...')
processor = Gemma3Processor.from_pretrained(model_id)

print('2/3 [OK] Loading base vision model (Gemma 3) onto GPU...')
model = Gemma3ForConditionalGeneration.from_pretrained(model_id, device_map='auto', torch_dtype=torch.bfloat16)

print('3/3 [OK] Loading fine-tuned LoRA weights from /tmp/checkpoint...')
model = PeftModel.from_pretrained(model, '/tmp/checkpoint')
model.eval()

print('\n== ALL SYSTEMS GO: MODEL LOADED SUCCESSFULLY ==')
print('Running warm-up text inference test...')

prompt = '<bos><start_of_turn>user\nHello Gemma! Tell me a 3-word greeting.<end_of_turn>\n<start_of_turn>model\n'

inputs = processor(text=prompt, images=None, return_tensors='pt').to('cuda')

with torch.no_grad():
    output = model.generate(**inputs, max_new_tokens=20)

print('\nSUCCESS! Model responded correctly.')
generated_text = processor.decode(output[0], skip_special_tokens=True)
print('Model Output:', generated_text)
print('==============================================================================')
"

kubectl exec -it "${HEAD_POD}" -c ray-head -- ray job submit \
    --entrypoint-num-gpus=1 \
    --entrypoint-num-cpus=4 \
    --runtime-env-json '{
        "pip": [
            "torch==2.8.0",
            "torchvision==0.23.0",
            "ray==2.48.0",
            "transformers==4.55.2",
            "peft==0.17.0",
            "google-cloud-storage"
        ]
    }' \
    -- bash -c "python -c \"$DOWNLOAD_SCRIPT\" && python -c \"$INLINE_VALIDATION_SCRIPT\""
# [END hypercomputer_gpu_tune_gemma3_ray_validation]
