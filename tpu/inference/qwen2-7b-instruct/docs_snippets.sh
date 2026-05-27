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

# [START hypercomputer_tpu_infer_qwen2_7b_qr_setup]
gcloud alpha compute tpus queued-resources create $QR_ID \
 --node-id $TPU_NAME \
 --project $PROJECT_ID \
 --zone $ZONE \
 --accelerator-type $TPU_TYPE \
 --runtime-version v2-alpha-tpuv6e
 # [END hypercomputer_tpu_infer_qwen2_7b_qr_setup]

LIMIT=60
count=0
while ! gcloud compute tpus queued-resources describe $QR_ID --project $PROJECT_ID --zone $ZONE | grep -q 'state: ACTIVE'; do
  if [ $count -ge $LIMIT ]; then
    echo "Timeout waiting for queued resource to become ACTIVE." >&2
    exit 1
  fi
  sleep 10
  count=$((count+1))
done

# [START hypercomputer_tpu_infer_qwen2_7b_qr_describe]
gcloud compute tpus queued-resources describe $QR_ID \
  --project $PROJECT_ID \
  --zone $ZONE
# [END hypercomputer_tpu_infer_qwen2_7b_qr_describe]

# [START hypercomputer_tpu_infer_qwen2_7b_ssh]
gcloud compute tpus tpu-vm ssh $TPU_NAME \
  --project $PROJECT_ID \
  --zone $ZONE
# [END hypercomputer_tpu_infer_qwen2_7b_ssh]

# [START hypercomputer_tpu_infer_qwen2_7b_logs]
sudo docker logs -f "${CONTAINER_NAME}"
# [END hypercomputer_tpu_infer_qwen2_7b_logs]

# [START hypercomputer_tpu_infer_qwen2_7b_qr_cleanup]
gcloud alpha compute tpus queued-resources delete $QR_ID \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --force
# [END hypercomputer_tpu_infer_qwen2_7b_qr_cleanup]
