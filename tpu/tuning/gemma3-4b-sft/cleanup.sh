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

NETWORK_NAME="${NETWORK:-default}"
FIREWALL_RULE_NAME="allow-ssh-from-iap-${NETWORK_NAME}"

# Remove all resources created by your sample.
# [START hypercomputer_tpu_tune_gemma3_sft_cleanup]
# 1. Delete TPU VM instance
echo "Deleting TPU VM instance: ${NAME}..."
gcloud alpha compute tpus tpu-vm delete "${NAME}" \
    --zone="${ZONE}" \
    --project="${PROJECT}" \
    --quiet || true

# 2. Delete IAP firewall rule
echo "Deleting firewall rule: ${FIREWALL_RULE_NAME}..."
gcloud compute firewall-rules delete "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT}" \
    --quiet || true

# 3. Delete custom VPC network (skip if using default network)
if [ "${NETWORK_NAME}" != "default" ]; then
  echo "Deleting custom VPC network: ${NETWORK_NAME}..."
  gcloud compute networks delete "${NETWORK_NAME}" \
      --project="${PROJECT}" \
      --quiet || true
else
  echo "Skipping VPC network deletion for '${NETWORK_NAME}' network."
fi
# [END hypercomputer_tpu_tune_gemma3_sft_cleanup]
