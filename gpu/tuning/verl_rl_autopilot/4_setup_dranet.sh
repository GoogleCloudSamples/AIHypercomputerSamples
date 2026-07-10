#!/bin/bash

set -euo pipefail

source 0_env.sh

# Generate ComputeClass YAML
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

echo "Applying ComputeClass..."
kubectl apply -f computeclass-dranet.yaml

echo "Applying ResourceClaimTemplate..."
kubectl apply -f resourceclaim-dranet.yaml

echo "DRANET setup complete."
