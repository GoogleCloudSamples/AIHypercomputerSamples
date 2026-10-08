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

# [START hypercomputer_gpu_train_ray_verl_clone]
git clone https://github.com/GoogleCloudSamples/AIHypercomputerSamples.git
# [END hypercomputer_gpu_train_ray_verl_clone]

# [START hypercomputer_gpu_train_ray_chdir_autopilot]
cd AIHypercomputerSamples/gpu/tuning/verl_rl_autopilot
# [END hypercomputer_gpu_train_ray_chdir_autopilot]

# [START hypercomputer_gpu_train_ray_chdir_std]
cd AIHypercomputerSamples/gpu/tuning/verl_rl_standard
# [END hypercomputer_gpu_train_ray_chdir_std]

# [START hypercomputer_gpu_train_ray_watch_pods]
watch kubectl get pods -n ${NAMESPACE}
# [END hypercomputer_gpu_train_ray_watch_pods]

# [START hypercomputer_gpu_train_ray_logs_data_prep]
kubectl logs -n ${NAMESPACE} -l job-name=data-prep-job -f
# [END hypercomputer_gpu_train_ray_logs_data_prep]

# [START hypercomputer_gpu_train_ray_verl_auto_job_logs]
ray job logs "${JOB_ID}" --address "http://localhost:8265" --follow
# [END hypercomputer_gpu_train_ray_verl_auto_job_logs]

# [START hypercomputer_gpu_train_ray_verl_auto_verify_checkpoints]
gcloud storage ls "gs://${GS_BUCKET}/verl/checkpoints/"
# [END hypercomputer_gpu_train_ray_verl_auto_verify_checkpoints]

# [START hypercomputer_gpu_train_ray_verl_auto_kill_port_forward]
kill ${PF_LOOP_PID}
# [END hypercomputer_gpu_train_ray_verl_auto_kill_port_forward]

# [START hypercomputer_gpu_train_ray_verl_std_kill_port_forward]
kill ${PF_PID}
# [END hypercomputer_gpu_train_ray_verl_std_kill_port_forward]