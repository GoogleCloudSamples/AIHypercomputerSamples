# Fine-tune Gemma 3 on GKE

This code sample is intended for AI/ML engineers and demonstrates how to run Gemma 3 fine-tuning using a Google Kubernetes Engine (GKE) cluster.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

## Architecture and Workload

This sample provisions a GKE cluster with GPU node pools to run the fine-tuning workload. The workload uses PyTorch and Accelerate with FSDP, orchestrated as a Kubernetes Job. It uses Artifact Registry for the container image and Google Cloud Storage for checkpoints and data.

The sample includes the following scripts:

* `0_env.sh`: Configures starting environment variables (project ID, cluster name, token).
* `1_setup_cluster.sh`: Provisions the GKE cluster, configures node pools, sets up secrets, and prepares the Kubernetes environment.
* `2_build_and_deploy.sh`: Builds the container image, pushes it to Artifact Registry, and deploys the fine-tuning Job.
* `cleanup.sh`: Deletes the GKE cluster and cleans up all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Google Kubernetes Engine (GKE) cluster and GPU Virtual Machines
  - Artifact Registry for storing container images
  - Google Cloud Storage buckets
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for the required hardware in your chosen region.
* Specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools like cluster-toolkit or kubectl, depending on the environment.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables (e.g., `PROJECT_ID`, `ZONE`, and `HF_TOKEN`).
   
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
  
* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
