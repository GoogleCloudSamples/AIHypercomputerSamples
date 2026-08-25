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

# Set your environment variables here.
# DO NOT PUT ANY SECRET VALUES HERE!
# [START hypercomputer_tpu_tune_gemma3_sft_env]
export PROJECT="YOUR_PROJECT_ID"
export ZONE="YOUR_ZONE"
export RESERVATION="YOUR_RESERVATION_NAME"
export NAME="YOUR_TPU_NAME"
# [END hypercomputer_tpu_tune_gemma3_sft_env]
export HF_TOKEN="YOUR_HF_TOKEN"
