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

# [START hypercomputer_gpu_train_qwen_megatron_gke_auth]
gcloud auth login
gcloud auth application-default login
# [END hypercomputer_gpu_train_qwen_megatron_gke_auth]

# [START hypercomputer_gpu_train_qwen_megatron_gke_download_manifests]
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/training/qwen-megatron-gke/qwen3-data-prep.yaml
curl -LO https://raw.githubusercontent.com/GoogleCloudSamples/AIHypercomputerSamples/main/gpu/training/qwen-megatron-gke/qwen3-30b-a3b-pretrain-jobset.yaml
# [END hypercomputer_gpu_train_qwen_megatron_gke_download_manifests]

# Optional (run from the cluster-toolkit/ directory): Verify GPUDirect RDMA (gIB) bandwidth with the bundled 2-node NCCL test
# [START hypercomputer_gpu_train_qwen_megatron_gke_nccl_test]
kubectl create -f examples/gke-a4/nccl-jobset-example.yaml
kubectl wait --for=condition=Completed jobset -l kueue.x-k8s.io/queue-name=a4 --timeout=600s
kubectl logs -l batch.kubernetes.io/job-completion-index=0
kubectl delete jobset -l kueue.x-k8s.io/queue-name=a4
# [END hypercomputer_gpu_train_qwen_megatron_gke_nccl_test]

# Stream live per-iteration loss and throughput logs on global Rank 15 (use index=0 for checkpoint save progress)
# [START hypercomputer_gpu_train_qwen_megatron_gke_pretrain_logs_live]
kubectl logs -f -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b,batch.kubernetes.io/job-completion-index=1 -c megatron-bridge
# [END hypercomputer_gpu_train_qwen_megatron_gke_pretrain_logs_live]

# Stream live Node 0 logs while waiting for checkpoint resumption
# [START hypercomputer_gpu_train_qwen_megatron_gke_resume_logs_live]
kubectl logs -f -l jobset.sigs.k8s.io/jobset-name=qwen3-30b-a3b,batch.kubernetes.io/job-completion-index=0 -c megatron-bridge
# [END hypercomputer_gpu_train_qwen_megatron_gke_resume_logs_live]
