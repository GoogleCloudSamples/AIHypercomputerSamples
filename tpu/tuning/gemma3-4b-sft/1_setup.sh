#!/bin/bash
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

# [START hypercomputer_tpu_tune_gemma3_sft_create]
gcloud compute instances create "${NAME}" \
    --zone="${ZONE}" \
    --project="${PROJECT}" \
    --network="${NETWORK}" \
    --tags="${NAME}" \
    --machine-type=ct6e-standard-8t \
    --image-project=ubuntu-os-accelerator-images \
    --image-family=ubuntu-accel-2204-amd64-tpu-v5e-v5p-v6e \
    --boot-disk-size=200GB \
    --maintenance-policy=TERMINATE \
    --instance-termination-action=DELETE \
    --provisioning-model=RESERVATION_BOUND \
    --reservation-affinity=specific \
    --reservation="${RESERVATION}"
# [END hypercomputer_tpu_tune_gemma3_sft_create]

LIMIT=60
count=0
while [ "$(gcloud compute instances describe "${NAME}" --project "${PROJECT}" --zone "${ZONE}" --format='value(status)')" != "RUNNING" ]; do
  if [ $count -ge $LIMIT ]; then
    echo "Timeout waiting for TPU instance to become RUNNING." >&2
    exit 1
  fi
  sleep 10
  count=$((count+1))
done
