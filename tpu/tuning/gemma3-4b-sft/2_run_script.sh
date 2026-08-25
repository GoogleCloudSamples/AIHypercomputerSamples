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

gcloud alpha compute tpus tpu-vm scp run_on_vm.sh "${NAME}":~/ \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --tunnel-through-iap

gcloud alpha compute tpus tpu-vm ssh "$NAME" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --tunnel-through-iap \
    --command="UV_HTTP_TIMEOUT=300 UV_CONCURRENT_DOWNLOADS=1 YOUR_HF_TOKEN=$HF_TOKEN bash ~/run_on_vm.sh"
