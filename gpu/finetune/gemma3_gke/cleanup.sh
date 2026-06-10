#!/bin/bash
source 0_env.sh

set -x

kubectl delete job finetune-job --ignore-not-found=true || true
gcloud container clusters delete "${CLUSTER_NAME}" \
    --region="${REGION}" --quiet || true
