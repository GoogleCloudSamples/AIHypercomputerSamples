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

#!/bin/bash

set -euo pipefail

# 1. Create GKE Cluster in Autopilot
# [START hypercomputer_gpu_tune_gemma3_ray_create_cluster]
gcloud container clusters create-auto $CLUSTER_NAME \
    --enable-ray-operator \
    --enable-ray-cluster-monitoring \
    --enable-ray-cluster-logging \
    --location=$REGION
# [END hypercomputer_gpu_tune_gemma3_ray_create_cluster]

sleep 15

echo "Verifying cluster readiness..."
MAX_ATTEMPTS=3
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    CURRENT_STATUS=$(gcloud container clusters describe "$CLUSTER_NAME" --region "$REGION" --format="value(status)")
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Cluster status is '$CURRENT_STATUS'"

    if [ "$CURRENT_STATUS" = "RUNNING" ]; then
        echo "Verification passed! Cluster '$CLUSTER_NAME' is fully operational."
        break
    elif [ "$CURRENT_STATUS" = "PROVISIONING" ] || [ "$CURRENT_STATUS" = "RECONCILING" ]; then
        echo "Cluster is still stabilizing. Waiting 10 seconds..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    else
        echo "Critical Error: Cluster entered an unexpected state: '$CURRENT_STATUS'"
        exit 1
    fi
done

if [ "$CURRENT_STATUS" != "RUNNING" ]; then
    echo "Error: Cluster failed to reach RUNNING state within the validation window."
    exit 1
fi

# 2. Get credentials
# [START hypercomputer_gpu_tune_gemma3_ray_get_creds]
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION
# [END hypercomputer_gpu_tune_gemma3_ray_get_creds]

# 3. Create HF Secret
# [START hypercomputer_gpu_tune_gemma3_ray_create_secret]
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HF_TOKEN} \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_ray_create_secret]

# 4. Create Google Cloud Storage Bucket
# [START hypercomputer_gpu_tune_gemma3_ray_create_gcs_bucket]
gcloud storage buckets create gs://$GCS_BUCKET --location=$REGION
# [END hypercomputer_gpu_tune_gemma3_ray_create_gcs_bucket]

echo "Verifying bucket creation..."
if gcloud storage buckets describe "gs://$GCS_BUCKET" > /dev/null 2>&1; then
    echo "Success! Bucket gs://$GCS_BUCKET is created and accessible."
else
    echo "Error: Bucket gs://$GCS_BUCKET could not be found or is inaccessible."
    exit 1
fi

# 5. Create Google Cloud Storage Account
# [START hypercomputer_gpu_tune_gemma3_ray_create_gsa_account]
gcloud iam service-accounts create $GSA_NAME \
    --project=$PROJECT_ID \
    --description="Account for Ray to save Gemma training results" \
    --display-name="Ray Gemma Training SA"
# [END hypercomputer_gpu_tune_gemma3_ray_create_gsa_account]
echo "Waiting for GCS Account replication"
SA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
MAX_IAM_ATTEMPTS=12
IAM_ATTEMPT=1

while [ $IAM_ATTEMPT -le $MAX_IAM_ATTEMPTS ]; do
    if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo "GCS Account is ready"
        break
    fi
    echo "GCS Account is not ready (Attempt $IAM_ATTEMPT/$MAX_IAM_ATTEMPTS). Waiting 5 seconds..."
    sleep 5
    IAM_ATTEMPT=$((IAM_ATTEMPT + 1))
done

if [ $IAM_ATTEMPT -gt $MAX_IAM_ATTEMPTS ]; then
    echo "Critical error: The GCS Account did not replicate within the allotted time."
    exit 1
fi

echo "Waiting 15 seconds for Cloud Storage synchronization"
sleep 15

# 6. Add Storage Admin role to GSA on the specific bucket
# [START hypercomputer_gpu_tune_gemma3_ray_storage_admin_role]
gcloud storage buckets add-iam-policy-binding gs://${GCS_BUCKET#gs://} \
    --member="serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"
# [END hypercomputer_gpu_tune_gemma3_ray_storage_admin_role]

# 7. Create Kubernetes Service Account
# [START hypercomputer_gpu_tune_gemma3_ray_create_sa_account]
kubectl create serviceaccount $RAY_SA \
    --dry-run=client -o yaml | kubectl apply -f -
# [END hypercomputer_gpu_tune_gemma3_ray_create_sa_account]

# 8. Bind KSA and GSA via Workload Identity
# [START hypercomputer_gpu_tune_gemma3_ray_wi]
gcloud iam service-accounts add-iam-policy-binding $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
    --project=$PROJECT_ID \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/$RAY_SA]"
# [END hypercomputer_gpu_tune_gemma3_ray_wi]

# 9. Annotate Kubernetes Service Account
# [START hypercomputer_gpu_tune_gemma3_ray_annotate_sa_account]
kubectl annotate serviceaccount $RAY_SA iam.gke.io/gcp-service-account=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com --overwrite
# [END hypercomputer_gpu_tune_gemma3_ray_annonate_sa_account]

# 10. Protection against Race Condition
# [START hypercomputer_gpu_tune_gemma3_ray_rc]
echo "Waiting 30 seconds for Workload Identity IAM replication..."
sleep 30
# [END hypercomputer_gpu_tune_gemma3_ray_rc]
