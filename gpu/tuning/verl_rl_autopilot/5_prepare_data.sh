#!/bin/bash
set -euo pipefail
source 0_env.sh

# Apply Data Prep Job
echo "Applying Data Prep Job..."
envsubst < "data-prep-job.yaml" | kubectl apply -f -

echo "Job submitted. You can monitor it with:"
echo "  kubectl get jobs -n ${NAMESPACE} data-prep-job"
echo "  kubectl logs -n ${NAMESPACE} -l job-name=data-prep-job -f"
echo ""
echo "Waiting for job to complete..."
kubectl wait --for=condition=complete --timeout=3600s -n ${NAMESPACE} job/data-prep-job

echo "Data preparation job finished successfully."
