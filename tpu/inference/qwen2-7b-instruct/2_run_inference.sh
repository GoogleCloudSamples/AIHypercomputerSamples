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

gcloud compute tpus tpu-vm scp run_on_vm_inference.sh "${TPU_NAME}":~/ --zone $ZONE --project $PROJECT_ID

gcloud compute tpus tpu-vm ssh $TPU_NAME --zone $ZONE --project $PROJECT_ID --command="HF_TOKEN=$HF_TOKEN bash ~/run_on_vm_inference.sh"
