#!/bin/bash

export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export GPU_TYPE="nvidia-b200"
export CONTROL_PLANE_REGION="us-west3"
export NODE_ZONE="us-west3-c"
export CLUSTER_NAME="your-cluster-name"
export KSA_NAME="your-ksa-name"
export GS_BUCKET="verl-dranet-${PROJECT_ID}"
export NAMESPACE=default
export HF_TOKEN=""
export MACHINE_TYPE="a4-highgpu-8g"
export RESERVATION_NAME=""
