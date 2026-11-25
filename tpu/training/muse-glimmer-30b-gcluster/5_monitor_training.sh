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

export WORKLOAD_NAME="${WORKLOAD_NAME:-${CLUSTER_NAME}-mg30b}"

echo "[$(date)] ==================== Checking the status of ${WORKLOAD_NAME}... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_check_status]
kubectl get jobset,workloads
kubectl get pods
# [END hypercomputer_tpu_train_muse_glimmer_30b_check_status]

echo "[$(date)] ==================== Reading training metrics from Cloud Logging... ===================="
# Cloud Logging ingestion can lag behind the job, so wait until the per-step
# metric lines are available before printing them.
log_filter='resource.type="k8s_container" AND resource.labels.cluster_name="'$CLUSTER_NAME'" AND resource.labels.pod_name:"'$WORKLOAD_NAME'-main-job-0-0-" AND resource.labels.container_name="workload-container" AND textPayload:"step:"'
limit=20
count=0
until gcloud logging read "${log_filter}" --project "$PROJECT_ID" --freshness=1h --limit=1 --format='value(textPayload)' 2>/dev/null | grep -q 'step:'; do
  if [ "${count}" -ge "${limit}" ]; then
    echo "Error: no training metrics found in Cloud Logging for ${WORKLOAD_NAME}." >&2
    exit 1
  fi
  echo "Training metrics are not yet available in Cloud Logging. Waiting 30s..."
  sleep 30
  count=$((count + 1))
done

# [START hypercomputer_tpu_train_muse_glimmer_30b_read_metrics]
gcloud logging read 'resource.type="k8s_container" AND resource.labels.cluster_name="'$CLUSTER_NAME'" AND resource.labels.pod_name:"'$WORKLOAD_NAME'-main-job-0-0-" AND resource.labels.container_name="workload-container" AND textPayload:"step:"' \
  --project "$PROJECT_ID" --freshness=1h --order=asc --format='value(textPayload)'
# [END hypercomputer_tpu_train_muse_glimmer_30b_read_metrics]

echo "[$(date)] ==================== Listing training outputs in Cloud Storage... ===================="
# [START hypercomputer_tpu_train_muse_glimmer_30b_list_outputs]
gcloud storage ls -r "${BASE_OUTPUT_DIR}/${WORKLOAD_NAME}/"
# [END hypercomputer_tpu_train_muse_glimmer_30b_list_outputs]

echo "[$(date)] ==================== Monitoring completed. ===================="
