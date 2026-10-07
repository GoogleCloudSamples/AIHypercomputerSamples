# Fine-tune Gemma 4 on an A4 GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 4 (31B) model by using a GKE Autopilot cluster that is deployed on A4 VMs (NVIDIA B200 GPUs) on Google Cloud.

Note: This sample doesn't demonstrate how to prepare a dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample creates a GKE Autopilot cluster, builds a custom Docker image for fine-tuning using Accelerate and FSDP, and submits it as a Kubernetes Job. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables, such as the project ID, cluster region, and Hugging Face token.
* `1_setup_cluster.sh`: Creates the GKE Autopilot cluster, fetches credentials, creates a Kubernetes Secret for the Hugging Face token, and provisions an Artifact Registry repository.
* `2_build_and_deploy.sh`: Builds a custom container image using Cloud Build, deploys the fine-tuning Job, and monitors its execution.
* `*_validation.sh`: Checks the output logs of the job to ensure the training finished successfully.
* `cleanup.sh`: Terminates all created resources, including the cluster, Job, and Artifact Registry repository.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Fine-tune Gemma 4 on an A4 GKE cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma4-finetune-a4-gke-cluster).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Google Kubernetes Engine (GKE Autopilot)
  - Compute Engine (A4 VMs with NVIDIA B200 GPUs)
  - Cloud Build
  - Artifact Registry
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for A4 VMs in your chosen region.
  
* A valid Hugging Face token (HF_TOKEN) with access to the `google/gemma-4-31B-it` model.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `CLUSTER_NAME`, `CLUSTER_REGION`, `RESERVATION`, `HF_TOKEN`, and `ARTIFACT_REPO_LOCATION` variables.
   
   ```bash
   source 0_env.sh
   ```

2. Create the GKE Autopilot cluster, fetch credentials, and provision the Artifact Registry:

   ```bash
   ./1_setup_cluster.sh
   ```

3. Build the container image and deploy the fine-tuning Job:

   ```bash
   ./2_build_and_deploy.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to check the Kubernetes Job logs for the completion messages:

   ```bash
   ./*_validation.sh
   ```

2. You should see an output indicating `Validation Succeeded!`.

## Clean up

To clean up the resources created by this sample:

1. Delete the Job, GKE cluster, and Artifact Registry repository:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* [Fine-tune Gemma 4 on an A4 GKE cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma4-finetune-a4-gke-cluster)
