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

# Remove all resources created by the sample.
# [START hypercomputer_tpu_tune_gemma4_e4b_sft_cleanup]
export FIREWALL_RULE_NAME="allow-ssh-from-iap-${TPU_NAME}"

# 1. Delete the TPU instance
echo "Deleting TPU instance: ${TPU_NAME}..."
gcloud compute instances delete "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --quiet || true

# 2. Delete the IAP firewall rule
echo "Deleting firewall rule: ${FIREWALL_RULE_NAME}..."
gcloud compute firewall-rules delete "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT_ID}" \
    --quiet || true
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_cleanup]

LEFTOVER=0
if gcloud compute instances describe "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" >/dev/null 2>&1; then
  echo "ERROR: TPU instance ${TPU_NAME} still exists." >&2
  LEFTOVER=1
fi
if gcloud compute firewall-rules describe "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "ERROR: firewall rule ${FIREWALL_RULE_NAME} still exists." >&2
  LEFTOVER=1
fi
exit "${LEFTOVER}"
