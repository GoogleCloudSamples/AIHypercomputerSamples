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

echo "[$(date)] ==================== Downloading gcluster blueprint... ===================="
# [START hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]
wget https://raw.githubusercontent.com/GoogleCloudPlatform/cluster-toolkit/refs/heads/develop/examples/gke-tpu-v6e/gke-tpu-v6e-advanced.yaml -O gke-tpu-v6e-advanced.yaml
cat << 'EOF' > kueue-configuration.yaml.tftpl
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: "tpuv6e-flavor"
spec:
  nodeLabels:
    cloud.google.com/gke-tpu-accelerator: ${accelerator_type}
  tolerations:
  - effect: NoSchedule
    key: google.com/tpu
    value: "present"
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: "default-flavor"
spec: {}
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: "cluster-queue"
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["google.com/tpu"]
    flavors:
    - name: "tpuv6e-flavor"
      resources:
      - name: "google.com/tpu"
        nominalQuota: ${tpu_quota}
  - coveredResources: ["cpu", "memory"]
    flavors:
    - name: "default-flavor"
      resources:
      - name: "cpu"
        nominalQuota: "1000"
      - name: "memory"
        nominalQuota: "4000Gi"
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  namespace: ${namespace}
  name: "user-queue"
spec:
  clusterQueue: "cluster-queue"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: very-low
value: 100
globalDefault: false
description: "Very Low"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low
value: 250
globalDefault: false
description: "Low"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: medium
value: 500
globalDefault: false
description: "Medium"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high
value: 750
globalDefault: false
description: "High"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: very-high
value: 1000
globalDefault: false
description: "Very High"
EOF

echo "[$(date)] ==================== Configuring blueprint... ===================="
# We inject the environment variables into the downloaded YAML blueprint using sed.
sed -i "s/project_id:.*/project_id: ${PROJECT}/" gke-tpu-v6e-advanced.yaml
sed -i "s/deployment_name:.*/deployment_name: ${CLUSTER_NAME}/" gke-tpu-v6e-advanced.yaml
sed -i "s/region:.*/region: ${REGION}/" gke-tpu-v6e-advanced.yaml
sed -i "s/zone:.*/zone: ${ZONE}/" gke-tpu-v6e-advanced.yaml
sed -i "s/num_slices:.*/num_slices: ${CLUSTER_NODEPOOL_COUNT}/" gke-tpu-v6e-advanced.yaml
sed -i "s/tpu_topology:.*/tpu_topology: ${TOPOLOGY}/" gke-tpu-v6e-advanced.yaml
sed -i "s|authorized_cidr:.*|authorized_cidr: 0.0.0.0/0|" gke-tpu-v6e-advanced.yaml
sed -i "s/n2-standard-8/e2-standard-8/" gke-tpu-v6e-advanced.yaml

if [ -z "$RESERVATION" ] || [ "$RESERVATION" == "YOUR_RESERVATION_NAME" ]; then
    sed -i "s/reservation:.*/reservation: ''/" gke-tpu-v6e-advanced.yaml
else
    sed -i "s/reservation:.*/reservation: ${RESERVATION}/" gke-tpu-v6e-advanced.yaml
fi

echo "[$(date)] ==================== Deploying cluster with gcluster... ===================="
gcluster deploy gke-tpu-v6e-advanced.yaml -l IGNORE --auto-approve -w

# Fetch GKE cluster credentials for kubectl
gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${REGION} --project=${PROJECT}

# Configure docker and IAM for the service accounts created by cluster-toolkit
gcloud auth configure-docker gcr.io --quiet
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-wl-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:${CLUSTER_NAME}-gke-np-sa@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin" --quiet

# Disable host IPv6 across all GKE nodes to ensure C++ gRPC and Pathways communicate exclusively over IPv4
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: disable-ipv6-ds
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: disable-ipv6
  template:
    metadata:
      labels:
        name: disable-ipv6
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
      - operator: Exists
      containers:
      - name: disable-ipv6
        image: alpine:latest
        securityContext:
          privileged: true
        command:
        - /bin/sh
        - -c
        - |
          for dev in $(ls /sys/class/net); do
            sysctl -w net.ipv6.conf.$dev.disable_ipv6=1 2>/dev/null || true
            ip -6 addr flush dev $dev 2>/dev/null || true
          done
          sysctl -w net.ipv6.conf.all.disable_ipv6=1
          sysctl -w net.ipv6.conf.default.disable_ipv6=1
          sysctl -w net.ipv6.conf.lo.disable_ipv6=1
          echo "Disabled and flushed IPv6 on $(hostname)"
          sleep infinity
EOF
# [END hypercomputer_tpu_tune_qwen3_30b_rl_create_cluster]

echo "[$(date)] ==================== Cluster deployment completed. ===================="
