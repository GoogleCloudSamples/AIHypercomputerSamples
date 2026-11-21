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

# [START hypercomputer_gpu_tune_gemma4_ray_adc_login]
gcloud auth application-default login
# [END hypercomputer_gpu_tune_gemma4_ray_adc_login]

# [START hypercomputer_gpu_tune_gemma4_ray_monitor_pods]
kubectl get pods
# [END hypercomputer_gpu_tune_gemma4_ray_monitor_pods]

: <<'EOF'
# [START hypercomputer_gpu_tune_gemma4_ray_monitor_pods_output]
NAME                                   READY   STATUS    RESTARTS   AGE
gemma4-tuning-gpu-group-worker-s4h8f   2/2     Running   0          16m
gemma4-tuning-gpu-group-worker-stg5f   2/2     Running   0          5m34s
gemma4-tuning-head-zbdvp               2/2     Running   0          16m
# [END hypercomputer_gpu_tune_gemma4_ray_monitor_pods_output]
EOF

# [START hypercomputer_gpu_tune_gemma4_ray_monitor_logs]
kubectl logs -f job/gemma4-tuning-job
# [END hypercomputer_gpu_tune_gemma4_ray_monitor_logs]

: <<'EOF'
# [START hypercomputer_gpu_tune_gemma4_ray_monitor_logs_output]
2026-08-20 08:29:34,966 INFO cli.py:41 -- Job submission server address: http://gemma4-tuning-head-svc.default.svc.cluster.local:8265
2026-08-20 08:29:34,991 SUCC cli.py:65 -- ----------------------------------------------------
2026-08-20 08:29:34,991 SUCC cli.py:66 -- Job 'gemma4-tuning-job-82mm7' submitted successfully
2026-08-20 08:29:34,991 SUCC cli.py:67 -- ----------------------------------------------------
2026-08-20 08:29:34,992 INFO cli.py:291 -- Next steps
2026-08-20 08:29:34,992 INFO cli.py:292 -- Query the logs of the job:
2026-08-20 08:29:34,992 INFO cli.py:294 -- ray job logs gemma4-tuning-job-82mm7
2026-08-20 08:29:34,992 INFO cli.py:296 -- Query the status of the job:
2026-08-20 08:29:34,992 INFO cli.py:298 -- ray job status gemma4-tuning-job-82mm7
2026-08-20 08:29:34,992 INFO cli.py:300 -- Request the job to be stopped:
2026-08-20 08:29:34,992 INFO cli.py:302 -- ray job stop gemma4-tuning-job-82mm7
2026-08-20 08:29:35,003 INFO cli.py:312 -- Tailing logs until the job exits (disable with --no-wait):
2026-08-20 08:29:34,982 INFO job_manager.py:531 -- Runtime env is setting up.
Starting training task!
Commencing training!
2026-08-20 08:30:08,498 INFO worker.py:1606 -- Using address 10.76.0.17:6379 set in the environment variable RAY_ADDRESS
2026-08-20 08:30:08,506 INFO worker.py:1747 -- Connecting to existing Ray cluster at address: 10.76.0.17:6379...
2026-08-20 08:30:08,527 INFO worker.py:1918 -- Connected to Ray cluster. View the dashboard at 10.76.0.17:8265
2026-08-20 08:30:08,701 INFO tune.py:253 -- Initializing Ray automatically. For cluster usage or custom Ray initialization, call `ray.init(...)` before `<FrameworkTrainer>(...)`.

View detailed results here: gs://YOUR_GCS_BUCKET/gemma4_vision_train_2026_08_20_08_30_07
To visualize your results with TensorBoard, run: `tensorboard --logdir /mnt/local-storage/ray-tmp/session_2026-08-20_04-43-14_215096_1/artifacts/2026-08-20_08-30-08/gemma4_vision_train_2026_08_20_08_30_07/driver_artifacts`

Training started with configuration:
╭──────────────────────────────────────────────────────────────────────╮
│ Training config                                                      │
├──────────────────────────────────────────────────────────────────────┤
│ train_loop_config/accelerator_type                              B200 │
│ train_loop_config/dataset_name                  ...-descriptions-vlm │
│ train_loop_config/gcs_bucket                         YOUR_GCS_BUCKET │
│ train_loop_config/gradient_accumulation_steps                      4 │
│ train_loop_config/learning_rate                               0.0002 │
│ train_loop_config/logging_steps                                   10 │
│ train_loop_config/lora_alpha                                      16 │
│ train_loop_config/lora_dropout                                  0.05 │
│ train_loop_config/lora_r                                          16 │
│ train_loop_config/model_id                     google/gemma-4-E4B-it │
│ train_loop_config/num_train_epochs                                 3 │
│ train_loop_config/num_workers                                     16 │
│ train_loop_config/output_dir                   ...-e4b-seo-optimized │
│ train_loop_config/per_device_train_batch_size                      1 │
│ train_loop_config/save_steps                                     100 │
│ train_loop_config/save_strategy                                epoch │
╰──────────────────────────────────────────────────────────────────────╯
(RayTrainWorker pid=45455, ip=10.76.0.71) Setting up process group for: env:// [rank=0, world_size=16]
(TorchTrainer pid=45197, ip=10.76.0.71) Started distributed worker processes:
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45455) world_rank=0, local_rank=0, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45450) world_rank=1, local_rank=1, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45454) world_rank=2, local_rank=2, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45448) world_rank=3, local_rank=3, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45453) world_rank=4, local_rank=4, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45452) world_rank=5, local_rank=5, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45451) world_rank=6, local_rank=6, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=4c934ab2f646a578b03cc335586f30b943e811b645526a74c50bfca1, ip=10.76.0.71, pid=45449) world_rank=7, local_rank=7, node_rank=0
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45729) world_rank=8, local_rank=0, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45726) world_rank=9, local_rank=1, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45728) world_rank=10, local_rank=2, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45727) world_rank=11, local_rank=3, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45725) world_rank=12, local_rank=4, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45724) world_rank=13, local_rank=5, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45723) world_rank=14, local_rank=6, node_rank=1
(TorchTrainer pid=45197, ip=10.76.0.71) - (node_id=c0db52b44f891f3d6a1cedcbea4c6beb2c8434c66ef414dc15e65743, ip=10.76.0.135, pid=45722) world_rank=15, local_rank=7, node_rank=1

...

Training completed after 3 iterations at 2026-08-20 08:40:52. Total running time: 10min 43s
2026-08-20 08:40:53,113 INFO tune.py:1009 -- Wrote the latest version of all result files and experiment state to 'gs://YOUR_GCS_BUCKET/gemma4_vision_train_2026_08_20_08_30_07' in 0.1663s.
Final checkpoint: gs://YOUR_GCS_BUCKET/gemma4_vision_train_2026_08_20_08_30_07/TorchTrainer_.../checkpoint_000002

2026-08-20 08:40:58,304 SUCC cli.py:65 -- ---------------------------------------
2026-08-20 08:40:58,305 SUCC cli.py:66 -- Job 'gemma4-tuning-job-82mm7' succeeded
2026-08-20 08:40:58,305 SUCC cli.py:67 -- ---------------------------------------
# [END hypercomputer_gpu_tune_gemma4_ray_monitor_logs_output]
EOF

# [START hypercomputer_gpu_tune_gemma4_ray_port_forward]
kubectl port-forward service/gemma4-tuning-head-svc 8265:8265 > fwd.log 2>&1 &
# [END hypercomputer_gpu_tune_gemma4_ray_port_forward]

# [START hypercomputer_gpu_tune_gemma4_ray_delete_ray_cluster]
kubectl delete raycluster gemma4-tuning
# [END hypercomputer_gpu_tune_gemma4_ray_delete_ray_cluster]

# [START hypercomputer_gpu_tune_gemma4_ray_delete_gke_cluster]
gcloud container clusters delete "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}"
# [END hypercomputer_gpu_tune_gemma4_ray_delete_gke_cluster]

# [START hypercomputer_gpu_tune_gemma4_ray_delete_gcs_bucket]
gcloud storage rm -r "gs://${GCS_BUCKET}" --project="${PROJECT_ID}"
# [END hypercomputer_gpu_tune_gemma4_ray_delete_gcs_bucket]
