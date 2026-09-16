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

NETWORK_NAME="${NETWORK}"
FIREWALL_RULE_NAME="allow-ssh-from-iap-${NAME}"

FIREWALL_EXISTS=$(gcloud compute firewall-rules list \
  --project="${PROJECT}" \
  --filter="name=${FIREWALL_RULE_NAME} AND network=${NETWORK_NAME}" \
  --format="value(name)" 2>/dev/null || echo "")

if [ -z "${FIREWALL_EXISTS}" ]; then
  echo "Creating missing firewall rule '${FIREWALL_RULE_NAME}' for network ${NETWORK_NAME}..."
  gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT}" \
    --network="${NETWORK_NAME}" \
    --direction=INGRESS \
    --action=allow \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-tags="${NAME}" \
    --description="Allow SSH ingress from Google Cloud Identity-Aware Proxy (IAP) for ${NETWORK_NAME}"
  echo "Firewall rule created. Waiting 20s for VPC propagation..."
  sleep 20
else
  echo "Firewall rule '${FIREWALL_RULE_NAME}' already exists for this network. Skipping creation."
fi

gcloud alpha compute tpus tpu-vm scp run_on_vm.sh "${NAME}":~/ \
    --zone="${ZONE}" \
    --project="${PROJECT}" \
    --tunnel-through-iap

gcloud alpha compute tpus tpu-vm ssh "${NAME}" \
    --zone="${ZONE}" \
    --project="${PROJECT}" \
    --tunnel-through-iap \
    --command="UV_HTTP_TIMEOUT=300 UV_CONCURRENT_DOWNLOADS=1 YOUR_HF_TOKEN=$HF_TOKEN bash ~/run_on_vm.sh"
