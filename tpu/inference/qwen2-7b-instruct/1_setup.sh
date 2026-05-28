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

# [START hypercomputer_tpu_infer_qwen2_7b_res_setup]
gcloud alpha compute tpus tpu-vm create $TPU_NAME \
    --zone=$ZONE \
    --project $PROJECT_ID \
    --accelerator-type=$TPU_TYPE \
    --version=v2-alpha-tpuv6e \
    --provisioning-model=reservation-bound \
    --reservation=$RESERVATION
# [END hypercomputer_tpu_infer_qwen2_7b_res_setup]

LIMIT=60
count=0
while ! gcloud compute tpus tpu-vm describe $TPU_NAME --project $PROJECT_ID --zone $ZONE | grep -q 'state: READY'; do
  if [ $count -ge $LIMIT ]; then
    echo "Timeout waiting for TPU to become READY." >&2
    exit 1
  fi
  sleep 10
  count=$((count+1))
done
