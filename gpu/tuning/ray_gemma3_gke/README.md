# Fine-tune Gemma 3 with Ray on GKE

This code sample is intended for AI/ML engineers and demonstrates how to run Gemma 3 fine-tuning using Ray on a Google Kubernetes Engine (GKE) cluster.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

## Architecture and Workload

This sample provisions a GKE cluster and deploys a Ray cluster on top to manage distributed fine-tuning of the Gemma 3 model. It uses GPU-enabled Virtual Machines for the compute nodes and Google Cloud Storage for datasets and checkpointing.

The sample includes the following scripts:

* `0_env.sh`: Configures environment variables (project ID, cluster name, token).
* `1_setup.sh`: Provisions the GKE cluster, configures the node pools, sets up necessary secrets, and deploys the Ray cluster environment.
* `2_deploy_model.sh`: Submits the fine-tuning workload to the Ray cluster and initiates the training job.
* `cleanup.sh`: Deletes the GKE cluster, the Ray environment, and all associated Google Cloud resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use Ray to fine-tune Gemma 3 for vision tasks on GKE](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/use-ray-fine-tune-gemma-vision-task-gke).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Google Kubernetes Engine (GKE) cluster and GPU Virtual Machines
  - Google Cloud Storage buckets
  - Persistent disks
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for the required hardware in your chosen region.
* Specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools like cluster-toolkit or kubectl, depending on the environment.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables (e.g., `PROJECT_ID`, `ZONE`, and `HF_TOKEN`).
   
   ```bash
   source 0_env.sh
   ```

2. Run `./1_setup.sh`:
   
   ```bash
   ./1_setup.sh
   ```

3. Run `./2_deploy_model.sh`:
   
   ```bash
   ./2_deploy_model.sh
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
  
* [Use Ray to fine-tune Gemma 3 for vision tasks on GKE](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/use-ray-fine-tune-gemma-vision-task-gke)