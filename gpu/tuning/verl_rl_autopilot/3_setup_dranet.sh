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

source 0_env.sh

# Generate ComputeClass YAML
# [START hypercomputer_gpu_train_ray_verl_auto_create_computeclass]
echo "Generating computeclass-dranet.yaml..."
cat <<EOF > computeclass-dranet.yaml
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata:
  name: dranet-a4-computeclass-v3
spec:
  nodePoolAutoCreation:
    enabled: true
  nodePoolConfig:
    dra:
      networking:
        enabled: true
  priorities:
  - machineType: ${MACHINE_TYPE}
    gpu:
      count: 8
      type: ${GPU_TYPE}
    acceleratorNetworkProfile: auto
EOF

if [ -n "${RESERVATION_NAME:-}" ]; then
  echo "Adding reservation affinity for ${RESERVATION_NAME} to ComputeClass..."
  cat <<EOF >> computeclass-dranet.yaml
    reservations:
      affinity: Specific
      specific:
      - name: ${RESERVATION_NAME}
        project: ${PROJECT_ID}
EOF
fi
# [END hypercomputer_gpu_train_ray_verl_auto_create_computeclass]

# [START hypercomputer_gpu_train_ray_verl_auto_setup_dranet]
echo "Applying ComputeClass..."
kubectl apply -f computeclass-dranet.yaml

echo "Applying ResourceClaimTemplate..."
kubectl apply -f resourceclaim-dranet.yaml
# [END hypercomputer_gpu_train_ray_verl_auto_setup_dranet]

echo "DRANET setup complete."
