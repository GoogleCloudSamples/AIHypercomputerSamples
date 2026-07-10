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

# ========== Deploy Ray Cluster ==========

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_git_clone]
git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples.git
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_git_clone]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_navigate_working_dir]
cd kubernetes-engine-samples/ai-ml/nemo-rl-on-gke/nemoRL
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_navigate_working_dir]

# ========== Launch the Job ==========

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_launch_ray_session]
kubectl ray session ray-cluster-kuberay
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_launch_ray_session]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_job_submit]
bash gemma3-27b-it/gemma3-27b-gsm8k.sh
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_job_submit]


# ========== Monitor the Job ==========

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_enter_container]
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o name) -c ray-head -- bash
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_enter_container]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_install_tree]
apt update && apt install -y tree
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_install_tree]

# ========== Cleanup ==========

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_ray_cluster_cleanup]
helm delete ray-cluster
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_ray_cluster_cleanup]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_gke_cluster_cleanup]
gcloud container clusters delete ${CLUSTER_NAME} \
    --location=${CONTROL_PLANE_REGION} \
    --quiet
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_gke_cluster_cleanup]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_cleanup]
gcloud lustre instances delete ${LUSTRE_NAME} --location=${NODE_ZONE} --quiet
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_cleanup]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_vpc_peering_cleanup]
gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=${NETWORK}
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_vpc_peering_cleanup]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_ip_cleanup]
gcloud compute addresses delete ${LUSTRE_NAME}-range --global --quiet
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_lustre_ip_cleanup]

# [START hypercomputer_gpu_tune_gemma3_27b_nemo_rl_subnets_cleanup]
gcloud compute networks subnets delete ${GVNIC_NETWORK_PREFIX}-sub \
    --region=${CONTROL_PLANE_REGION} --quiet

for N in $(seq 0 7); do
  gcloud compute networks subnets delete ${RDMA_NETWORK_PREFIX}-sub-$N \
    --region=${CONTROL_PLANE_REGION} --quiet &
done
wait
# [END hypercomputer_gpu_tune_gemma3_27b_nemo_rl_subnets_cleanup]