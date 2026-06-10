#!/bin/bash
source 0_env.sh

set -e
set -x

# 1. Build and Submit
gcloud builds submit .

# 2. Deploy Job
envsubst < finetune.yaml | kubectl apply -f -
