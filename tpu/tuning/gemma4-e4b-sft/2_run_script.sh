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

VM_SCRIPT_TIMEOUT_SECONDS=6000

FIREWALL_EXISTS=$(gcloud compute firewall-rules list \
    --project="${PROJECT_ID}" \
    --filter="name=allow-ssh-from-iap-${TPU_NAME} AND network=${NETWORK}" \
    --format="value(name)" 2>/dev/null || echo "")

if [ -z "${FIREWALL_EXISTS}" ]; then
# [START hypercomputer_tpu_tune_gemma4_e4b_sft_firewall]
export FIREWALL_RULE_NAME="allow-ssh-from-iap-${TPU_NAME}"
gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT_ID}" \
    --network="${NETWORK}" \
    --direction=INGRESS \
    --action=allow \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-tags="${TPU_NAME}" \
    --description="Allow SSH from Identity-Aware Proxy (IAP) to ${TPU_NAME}"
# [END hypercomputer_tpu_tune_gemma4_e4b_sft_firewall]
  echo "Firewall rule created. Waiting 20s for VPC propagation..."
  sleep 20
else
  echo "Firewall rule '${FIREWALL_EXISTS}' already exists for network ${NETWORK}. Skipping creation."
fi

deadline=$((SECONDS + 300))
until timeout 60 gcloud compute ssh "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --quiet \
    --command="true" </dev/null >/dev/null 2>&1; do
  if [ "${SECONDS}" -ge "${deadline}" ]; then
    echo "Timeout waiting for SSH on ${TPU_NAME}." >&2
    exit 1
  fi
  sleep 10
done

timeout 300 gcloud compute scp run_on_vm.sh "${TPU_NAME}":~/ \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --quiet </dev/null

timeout $((VM_SCRIPT_TIMEOUT_SECONDS + 300)) gcloud compute ssh "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --quiet \
    --ssh-flag="-o ServerAliveInterval=30" \
    --ssh-flag="-o ServerAliveCountMax=20" \
    --command="bash -o pipefail -c 'UV_HTTP_TIMEOUT=300 UV_CONCURRENT_DOWNLOADS=1 YOUR_HF_TOKEN=${HF_TOKEN} timeout --kill-after=60 ${VM_SCRIPT_TIMEOUT_SECONDS} bash ~/run_on_vm.sh 2>&1 | tee ~/run_on_vm.log'" </dev/null
