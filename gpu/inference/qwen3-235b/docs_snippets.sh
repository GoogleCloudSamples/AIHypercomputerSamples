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

# [START hypercomputer_gpu_infer_qwen3_port_forward]
kubectl port-forward service/qwen3-service 8000:8000
# [END hypercomputer_gpu_infer_qwen3_port_forward]

# [START hypercomputer_gpu_infer_qwen3_deploy_cleanup]
kubectl delete -f qwen3-235b-deploy.yaml
kubectl delete -f qwen3-model-loader.yaml
kubectl delete secret hf-secret
kubectl delete serviceaccount qwen-ksa

gcloud iam service-accounts delete qwen-gcs-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --project=$PROJECT_ID --quiet

gcloud storage rm --recursive gs://$GCS_BUCKET_NAME
# [END hypercomputer_gpu_infer_qwen3_deploy_cleanup]
