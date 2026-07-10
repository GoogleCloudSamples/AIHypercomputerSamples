#!/bin/bash

export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export GPU_TYPE="nvidia-b200"
export CONTROL_PLANE_REGION="us-west3"
export NODE_ZONE="us-west3-c"
export CLUSTER_NAME="your-cluster-name"
export KSA_NAME="standard-verl-ksa"
export GS_BUCKET="verl-standard-${PROJECT_ID}"
export NAMESPACE=default
export HF_TOKEN=""
export MACHINE_TYPE="a4-highgpu-8g"
export RESERVATION=""

export GVNIC_NETWORK_PREFIX="standard-gvnic"
export RDMA_NETWORK_PREFIX="standard-rdma"
