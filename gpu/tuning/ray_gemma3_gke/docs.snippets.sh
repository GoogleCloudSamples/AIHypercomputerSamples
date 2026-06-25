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
#
# [START hypercomputer_gpu_tune_gemma3_ray_monitor_pods]
kubectl get pods
# [END hypercomputer_gpu_tune_gemma3_ray_monitor_pods]

# [START hypercomputer_gpu_tune_gemma3_ray_monitor_logs]
kubectl logs -f <test-ray-job-UNIQUE_ID>
# [END hypercomputer_gpu_tune_gemma3_ray_monitor_logs]

# [START hypercomputer_gpu_tune_gemma3_ray_port_forward]
kubectl port-forward service/gemma3-tuning-head-svc 8265:8265 > fwd.log 2>&1 &
# [END hypercomputer_gpu_tune_gemma3_ray_port_forward]
