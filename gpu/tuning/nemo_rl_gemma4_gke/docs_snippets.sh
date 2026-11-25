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

# shellcheck disable=SC2034,SC2164,SC2317

set -euo pipefail

# ========== Deploy Ray Cluster ==========

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_git_clone]
git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples.git
git -C kubernetes-engine-samples checkout "${NEMO_RL_CHART_COMMIT}"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_git_clone]

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_navigate_working_dir]
cd kubernetes-engine-samples/ai-ml/nemo-rl-on-gke/nemoRL
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_navigate_working_dir]

: <<'EOF'
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_nodes_verify_output]
NAME                                          READY STATUS RESTARTS AGE
ray-cluster-kuberay-head-sw7dp                2/2   Running 0      33h
ray-cluster-kuberay-worker-grp-0-worker-gkbxw 2/2   Running 0      33h
ray-cluster-kuberay-worker-grp-0-worker-kdg62 2/2   Running 0      33h
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_nodes_verify_output]
EOF

: <<'EOF'
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_cluster_verify_output]
NAME                 NAMESPACE DESIRED WORKERS AVAILABLE WORKERS CPUS GPUS TPUS MEMORY CONDITION STATUS AGE
ray-cluster-kuberay  default   2       2           618     17   0    1573741824k RayClusterProvisioned ready 33h
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_cluster_verify_output]
EOF

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_get_worker_pod]
WORKER_POD="$(kubectl get pods \
    -l ray.io/cluster=ray-cluster-kuberay,ray.io/node-type=worker \
    -o jsonpath='{.items[0].metadata.name}')"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_get_worker_pod]

# ========== Launch the Job ==========

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_launch_ray_session]
kubectl ray session ray-cluster-kuberay
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_launch_ray_session]

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_get_head_pod]
HEAD_POD_NAME="$(kubectl get pods --selector=ray.io/node-type=head \
    -o jsonpath='{.items[0].metadata.name}')"
WANDB_ENABLED="True"
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_get_head_pod]

# ========== Monitor the Job ==========

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_enter_container]
kubectl exec -it "$(kubectl get pods -l ray.io/node-type=head -o name)" -c ray-head -- \
    env RUN_NAME="${RUN_NAME}" bash
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_enter_container]

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_install_tree]
apt update && apt install -y tree
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_install_tree]

: <<'EOF'
# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_tree_output]
/data/nemo-rl-gemma4-12b
|-- logs
|   |-- exp_001
|   `-- tensorboard
|-- step_10
|   |-- config.yaml
|   |-- policy
|   |   |-- optimizer
|   |   |-- tokenizer
|   |   `-- weights
|   |-- train_dataloader.pt
|   `-- training_info.json
`-- step_5
    |-- config.yaml
    |-- policy
    |   |-- optimizer
    |   |-- tokenizer
    |   `-- weights
    |-- train_dataloader.pt
    `-- training_info.json
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_tree_output]
EOF

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_exit_container]
exit
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_exit_container]

# ========== Cleanup ==========

# [START hypercomputer_gpu_tune_gemma4_12b_nemo_rl_ray_cluster_cleanup]
helm delete ray-cluster
# [END hypercomputer_gpu_tune_gemma4_12b_nemo_rl_ray_cluster_cleanup]
