#!/bin/bash

set -euo pipefail

source 0_env.sh

# Check connection
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Error: Cannot connect to cluster. Run 'gcloud container clusters get-credentials' first."
  exit 1
fi

# Delete existing job if it exists
if kubectl get job data-prep-job -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "Job data-prep-job already exists. Deleting it to recreate..."
  kubectl delete job data-prep-job -n ${NAMESPACE}
  # Wait for it to be fully deleted
  kubectl wait --for=delete job/data-prep-job -n ${NAMESPACE} --timeout=60s || true
fi

# Apply Data Prep Job
echo "Applying Data Prep Job..."
# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsubst < "${SCRIPT_DIR}/data-prep-job.yaml" | kubectl apply -f -

echo "Job submitted. You can monitor it with:"
echo "  kubectl get jobs -n ${NAMESPACE} data-prep-job"
echo "  kubectl logs -n ${NAMESPACE} -l job-name=data-prep-job -f"
echo ""
echo "Waiting for job to complete..."
kubectl wait --for=condition=complete --timeout=3600s -n ${NAMESPACE} job/data-prep-job

echo "Data preparation job finished successfully."
