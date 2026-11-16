#!/bin/bash
#
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

# [START hypercomputer_gpu_train_mixtral_8x7b_auth]
gcloud auth login
gcloud auth application-default login
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
# [END hypercomputer_gpu_train_mixtral_8x7b_auth]

# [START hypercomputer_gpu_train_mixtral_8x7b_redeploy_overwrite]
./gcluster deploy -w \
  --skip-validators=test_gcsfuse_iam_role_exists \
  -d examples/gke-a4/gke-a4-deployment.yaml \
  examples/gke-a4/gke-a4.yaml \
  --auto-approve
# [END hypercomputer_gpu_train_mixtral_8x7b_redeploy_overwrite]

# [START hypercomputer_gpu_train_mixtral_8x7b_nccl_submit]
kubectl create -f examples/gke-a4/nccl-jobset-example.yaml
# [END hypercomputer_gpu_train_mixtral_8x7b_nccl_submit]

# [START hypercomputer_gpu_train_mixtral_8x7b_nccl_logs]
sleep 5
kubectl wait --for=condition=Ready pod -l batch.kubernetes.io/job-completion-index=0 --timeout=600s
kubectl wait --for=condition=Ready pod -l batch.kubernetes.io/job-completion-index=1 --timeout=600s
kubectl logs -f -l batch.kubernetes.io/job-completion-index=0
kubectl wait --for=condition=Completed jobset -l kueue.x-k8s.io/queue-name=a4 --timeout=600s
# [END hypercomputer_gpu_train_mixtral_8x7b_nccl_logs]

# [START hypercomputer_gpu_train_mixtral_8x7b_nccl_cleanup]
kubectl delete jobset -l kueue.x-k8s.io/queue-name=a4
# [END hypercomputer_gpu_train_mixtral_8x7b_nccl_cleanup]

# [START hypercomputer_gpu_train_mixtral_8x7b_stream_logs]
kubectl logs -f \
  -l jobset.sigs.k8s.io/jobset-name=mixtral-8x7b,batch.kubernetes.io/job-completion-index=1 \
  -c megatron-lm
# [END hypercomputer_gpu_train_mixtral_8x7b_stream_logs]
