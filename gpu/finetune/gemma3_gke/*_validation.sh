#!/bin/bash
source 0_env.sh

set -e
set -x

JOB_NAME="finetune-job"

echo "Waiting for Job ${JOB_NAME} to complete..."
kubectl wait --for=condition=complete job/${JOB_NAME} --timeout=14400s || {
    echo "Job failed or timed out. Fetching status and logs..."
    kubectl describe job ${JOB_NAME}
    kubectl logs job.batch/${JOB_NAME} --tail=200 || true
    exit 1
}

echo "Job completed. Fetching full logs for verification..."
kubectl logs job.batch/${JOB_NAME} > job_logs.txt

echo "Verifying logs..."
grep "Training finished." job_logs.txt
grep "Saving final model to" job_logs.txt

echo "Validation Succeeded!"
