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

set -euo pipefail

echo "[$(date)] ==================== Starting Cleanup... ===================="

: "${PROJECT_ID:?PROJECT_ID must be set, source 0_env.sh}"
: "${ZONE:?ZONE must be set, source 0_env.sh}"
: "${REGION:?REGION must be set, source 0_env.sh}"
: "${CLUSTER_NAME:?CLUSTER_NAME must be set, source 0_env.sh}"
: "${BUCKET_NAME:?BUCKET_NAME must be set, source 0_env.sh}"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
BASEDIR="$(dirname "${SCRIPT_PATH}")"
declare -r SCRIPT_PATH BASEDIR
cd "${BASEDIR}"
declare -r CLUSTER_TOOLKIT_PATH="${BASEDIR}/cluster_toolkit"
declare -r TOOLS_DIR="${BASEDIR}/.tools"
declare -r STATE_PREFIX="a4high-slurm/${CLUSTER_NAME}"

export PATH="${CLUSTER_TOOLKIT_PATH}:${TOOLS_DIR}:${PATH}"

declare -r CLUSTER_NETWORKS=("${CLUSTER_NAME}-net-0" "${CLUSTER_NAME}-rdma-net")

cleanup_network_firewalls() {
  local rules
  rules="$(gcloud compute firewall-rules list --project="${PROJECT_ID}" \
    --format="value(name,network.basename())" 2>/dev/null \
    | awk -v nets="${CLUSTER_NETWORKS[*]}" '
        BEGIN { split(nets, n, " "); for (i in n) want[n[i]] = 1 }
        ($2 in want) { print $1 }' || true)"
  if [[ -n "${rules}" ]]; then
    echo "[$(date)] Deleting firewall rules of the cluster networks: $(echo "${rules}" | tr "\n" " ")"
    echo "${rules}" | xargs -r gcloud compute firewall-rules delete --project="${PROJECT_ID}" --quiet || true
  fi
}

# 1. Delete Slurm cluster
DESTROY_FAILED=false
if [[ -x "${CLUSTER_TOOLKIT_PATH}/gcluster" && -d "${BASEDIR}/${CLUSTER_NAME}" ]]; then
  cleanup_network_firewalls
  echo "[$(date)] Destroying Slurm cluster ${CLUSTER_NAME}..."
  if ! gcluster destroy "${BASEDIR}/${CLUSTER_NAME}" --auto-approve; then
    DESTROY_FAILED=true
    echo "[$(date)] WARNING: gcluster destroy failed, deleting leftover resources directly."
  fi
else
  echo "[$(date)] No deployment directory found, deleting leftover resources directly."
fi

# 2. Delete leftover resources
gcloud compute instances list \
  --project="${PROJECT_ID}" \
  --filter="labels.ghpc_deployment=${CLUSTER_NAME}" \
  --format="value(name,zone.basename())" 2>/dev/null \
  | while read -r name zone; do
      echo "[$(date)] Deleting instance ${name} in ${zone}..."
      gcloud compute instances delete "${name}" --project="${PROJECT_ID}" --zone="${zone}" --quiet || true
    done || true

if gcloud lustre instances describe "${CLUSTER_NAME}-lustre" \
    --project="${PROJECT_ID}" --location="${ZONE}" &>/dev/null; then
  echo "[$(date)] Deleting Managed Lustre instance ${CLUSTER_NAME}-lustre..."
  gcloud lustre instances delete "${CLUSTER_NAME}-lustre" \
    --project="${PROJECT_ID}" --location="${ZONE}" --quiet || true
fi

if gcloud compute networks describe "${CLUSTER_NAME}-net-0" --project="${PROJECT_ID}" &>/dev/null; then
  for attempt in 1 2 3 4 5; do
    peering="$(gcloud services vpc-peerings list --project="${PROJECT_ID}" \
      --service=servicenetworking.googleapis.com \
      --network="${CLUSTER_NAME}-net-0" --format="value(peering)" 2>/dev/null || true)"
    if [ -z "${peering}" ]; then
      break
    fi
    echo "[$(date)] Deleting private service access peering on ${CLUSTER_NAME}-net-0 (attempt ${attempt})..."
    gcloud services vpc-peerings delete \
      --project="${PROJECT_ID}" \
      --service=servicenetworking.googleapis.com \
      --network="${CLUSTER_NAME}-net-0" \
      --quiet && break
    sleep 60
  done || true
fi
gcloud compute addresses delete "psconnect-${CLUSTER_NAME}-net-0" \
  --project="${PROJECT_ID}" --global --quiet 2>/dev/null || true

delete_network() {
  local net="$1"
  if ! gcloud compute networks describe "${net}" --project="${PROJECT_ID}" &>/dev/null; then
    return 0
  fi
  echo "[$(date)] Deleting leftover network ${net}..."
  gcloud compute routers delete "${net}-router" \
    --project="${PROJECT_ID}" --region="${REGION}" --quiet 2>/dev/null || true
  gcloud compute addresses list --project="${PROJECT_ID}" --regions="${REGION}" \
    --filter="name ~ ^${net}-nat-ips-" --format="value(name)" 2>/dev/null \
    | xargs -r gcloud compute addresses delete --project="${PROJECT_ID}" --region="${REGION}" --quiet || true
  gcloud compute networks subnets list --project="${PROJECT_ID}" --network="${net}" \
    --format="value(name,region.basename())" 2>/dev/null \
    | while read -r subnet region; do
        gcloud compute networks subnets delete "${subnet}" \
          --project="${PROJECT_ID}" --region="${region}" --quiet || true
      done || true
  local attempt
  for attempt in 1 2 3 4 5; do
    cleanup_network_firewalls
    if gcloud compute networks delete "${net}" --project="${PROJECT_ID}" --quiet; then
      return 0
    fi
    echo "[$(date)] Couldn't delete network ${net} (attempt ${attempt}), retrying..."
    sleep 15
  done
  echo "[$(date)] WARNING: couldn't delete network ${net}." >&2
}

for net in "${CLUSTER_NETWORKS[@]}"; do
  delete_network "${net}"
done

gcloud compute instance-templates list \
  --project="${PROJECT_ID}" \
  --filter="properties.labels.ghpc_deployment=${CLUSTER_NAME}" \
  --format="value(name)" 2>/dev/null \
  | while read -r template; do
      echo "[$(date)] Deleting instance template ${template}..."
      gcloud compute instance-templates delete "${template}" --project="${PROJECT_ID}" --quiet || true
    done || true

gcloud storage buckets list \
  --project="${PROJECT_ID}" \
  --filter="labels.ghpc_deployment=${CLUSTER_NAME}" \
  --format="value(name)" 2>/dev/null \
  | while read -r bucket; do
      echo "[$(date)] Deleting bucket gs://${bucket}..."
      gcloud storage rm --recursive "gs://${bucket}" --project="${PROJECT_ID}" --quiet || true
    done || true

if [[ "${DESTROY_FAILED}" == "true" ]]; then
  cleanup_network_firewalls
  echo "[$(date)] Retrying gcluster destroy of ${CLUSTER_NAME}..."
  if gcluster destroy "${BASEDIR}/${CLUSTER_NAME}" --auto-approve; then
    DESTROY_FAILED=false
  else
    echo "[$(date)] WARNING: gcluster destroy failed again."
  fi
fi

# 3. Delete the Terraform state and local files
if [[ "${DESTROY_FAILED}" == "true" ]]; then
  echo "[$(date)] WARNING: kept gs://${BUCKET_NAME}/${STATE_PREFIX} and ${BASEDIR}/${CLUSTER_NAME} because gcluster destroy failed. Run cleanup.sh again to retry."
else
  echo "[$(date)] Deleting Terraform state gs://${BUCKET_NAME}/${STATE_PREFIX}..."
  gcloud storage rm --recursive "gs://${BUCKET_NAME}/${STATE_PREFIX}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
  gcloud storage buckets delete "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" --quiet 2>/dev/null \
    || echo "[$(date)] Bucket gs://${BUCKET_NAME} was not deleted (it does not exist or is not empty)."

  echo "[$(date)] Cleaning up local files in ${BASEDIR}..."
  rm -rf "${BASEDIR:?}/${CLUSTER_NAME:?}"
  rm -rf "${CLUSTER_TOOLKIT_PATH}"
  rm -rf "${TOOLS_DIR}"
  rm -rf "${BASEDIR}/.ghpc"
fi
rm -f "${BASEDIR}/cluster_toolkit.tgz" "${BASEDIR}/slurm_job_id.txt" "${BASEDIR}/slurm_job_logs.txt"

echo "[$(date)] ==================== Cleanup Complete. ===================="
