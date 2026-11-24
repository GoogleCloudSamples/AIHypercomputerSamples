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

# Delete IAP firewall rule created by 2_run_script.sh (if present).
FIREWALL_RULE_NAME="allow-ssh-from-iap-${TPU_NAME}"
gcloud compute firewall-rules delete "${FIREWALL_RULE_NAME}" \
    --project="${PROJECT}" \
    --quiet 2>/dev/null || true

# Remove all resources created by your sample.
# [START hypercomputer_tpu_tune_llama_rl_cleanup]
gcloud compute instances delete "${TPU_NAME}" --zone="${ZONE}" --project="${PROJECT}" --quiet
# [END hypercomputer_tpu_tune_llama_rl_cleanup]
