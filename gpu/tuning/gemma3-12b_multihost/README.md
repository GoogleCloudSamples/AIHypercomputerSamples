# Fine-tune Gemma 3 (12B) across multiple hosts on GKE

This code sample is intended for AI/ML engineers and demonstrates how to run multihost fine-tuning for the Gemma 3 (12B) model using a Google Kubernetes Engine (GKE) cluster.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

This sample provisions a GKE cluster with GPU node pools to run a distributed fine-tuning workload. The workload uses PyTorch Fully Sharded Data Parallel (FSDP) and Accelerate, orchestrated as a Kubernetes Job using JobSet. It utilizes Cloud Storage for storing model artifacts and checkpoints. The sample includes the following files:

* `0_env.sh`: Configures environment variables such as the project ID, cluster name, and Hugging Face token.
* `1_setup_cluster.sh`: Provisions the GKE cluster, configures node pools, sets up secrets, and installs necessary Kubernetes components like JobSet.
* `2_build_and_deploy.sh`: Builds the container image, pushes it to Artifact Registry, and deploys the fine-tuning JobSet workload to the cluster.
* `*_validation.sh`: Validates that the fine-tuning workload ran successfully.
* `cleanup.sh`: Deletes the GKE cluster and removes all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Fine-tune Gemma 3 on a multi-host A4 GKE cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma3-finetune-a4-gke-multi-host-cluster).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Autopilot cluster and Compute Engine A4 Virtual Machines (VMs) (`a4-highgpu-8g` with 8 NVIDIA B200 GPUs per node)
  - Cloud Build
  - Artifact Registry for storing container images
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION`) for A4 VMs (`a4-highgpu-8g`, 8 NVIDIA B200 GPUs per node) in your chosen region.
* A valid Hugging Face token (`HF_TOKEN`) with access to the `google/gemma-3-12b-pt` model.
* The `gcloud`, `kubectl`, and `envsubst` CLI tools installed.
* Identity and Access Management (IAM) permissions to create GKE clusters, create Artifact Registry repositories, and submit Cloud Build builds.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `CLUSTER_NAME`, `CLUSTER_REGION`, `RESERVATION`, `HF_TOKEN`, and `ARTIFACT_REPO_LOCATION` variables.
   
   ```bash
   source 0_env.sh
   ```

2. Run `./1_setup_cluster.sh`:
   
   ```bash
   ./1_setup_cluster.sh
   ```

3. Run `./2_build_and_deploy.sh`:
   
   ```bash
   ./2_build_and_deploy.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to check the output logs:

   ```bash
   ./*_validation.sh
   ```

2. You should see an output indicating validation passed.

## Clean up

To clean up the resources created by this sample:

1. Terminate the cluster and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* [Fine-tune Gemma 3 on a multi-host A4 GKE cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma3-finetune-a4-gke-multi-host-cluster)
