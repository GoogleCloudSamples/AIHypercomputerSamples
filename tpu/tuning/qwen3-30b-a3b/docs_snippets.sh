#!/bin/bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# [START hypercomputer_tpu_tune_qwen3_30b_rl_monitor_pods]
kubectl get pod
# [END hypercomputer_tpu_tune_qwen3_30b_rl_monitor_pods]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_monitor_logs]
kubectl logs -f POD_NAME
# [END hypercomputer_tpu_tune_qwen3_30b_rl_monitor_logs]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_monitor_workload]
xpk workload list --cluster ${CLUSTER_NAME} --project ${PROJECT} --zone ${ZONE}
# [END hypercomputer_tpu_tune_qwen3_30b_rl_monitor_workload]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_monitor_train_logs]
kubectl logs -f qwen-training-pathways-head-0-0-HASH
# [END hypercomputer_tpu_tune_qwen3_30b_rl_monitor_train_logs]

# [START hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]
xpk cluster delete --cluster $CLUSTER_NAME --project $PROJECT --zone $ZONE --force

gcloud storage rm --recursive gs://$GCS_BUCKET

gcloud artifacts repositories delete maxtext-images --location=$REGION --project=$PROJECT --quiet
# [END hypercomputer_tpu_tune_qwen3_30b_rl_cleanup]
