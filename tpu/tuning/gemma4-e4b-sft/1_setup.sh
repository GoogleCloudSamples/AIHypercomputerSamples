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

# [START hypercomputer_tpu_tune_gemma4_e4b_sft_create]
gcloud compute instances create "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --network="${NETWORK}" \
    --tags="${TPU_NAME}" \
    --machine-type="${MACHINE_TYPE}" \
    --image-project="${IMAGE_PROJECT}" \
    --image-family="${IMAGE_FAMILY}" \
    --boot-disk-size="${BOOT_DISK_SIZE}" \
    --maintenance-policy=TERMINATE \
    --instance-termination-action=DELETE \
    --provisioning-model=RESERVATION_BOUND \
    --reservation-affinity=specific \
    --reservation="${RESERVATION}"
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_create]

deadline=$((SECONDS + 600))
until [ "$(timeout 60 gcloud compute instances describe "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --format='value(status)' </dev/null 2>/dev/null || echo "PENDING")" = "RUNNING" ]; do
  if [ "${SECONDS}" -ge "${deadline}" ]; then
    echo "Timeout waiting for instance ${TPU_NAME} to become RUNNING." >&2
    timeout 60 gcloud compute instances describe "${TPU_NAME}" \
        --project="${PROJECT_ID}" \
        --zone="${ZONE}" \
        --format='yaml(status,statusMessage,lastStartTimestamp)' </dev/null >&2 || true
    exit 1
  fi
  sleep 10
done
echo "Instance ${TPU_NAME} is RUNNING."
