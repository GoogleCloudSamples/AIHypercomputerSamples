# Fine-tune Mixtral 8x7B on a Slurm cluster

This code sample is intended for AI/ML engineers and demonstrates how to run Mixtral 8x7B fine-tuning using a Slurm cluster on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

This sample provisions a Slurm cluster using Cluster Toolkit. The architecture uses A4 High GPU (`a4-highgpu-8g`) instances for the compute nodes, a Cloud Storage bucket for storage, and Filestore for shared cluster storage. The workload distributes fine-tuning across the GPUs using a Slurm `sbatch` script. The sample includes the following files:

* `0_env.sh`: Configures environment variables, including the project ID, zone, and Hugging Face token.
* `1_deploy_cluster.sh`: Uses Cluster Toolkit to deploy the Slurm cluster infrastructure and storage.
* `2_run_job.sh`: Submits the `sbatch` job to distribute the fine-tuning workload across the cluster.
* `*_validation.sh`: Validates that the fine-tuning workload ran successfully.
* `cleanup.sh`: Deletes the Slurm cluster and all associated resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use FSDP to fine-tune Mixtral-8x7B on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/fsdp-mixtral-8x7b).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Compute Engine A4 (`a4-highgpu-8g`) Virtual Machines (VMs)
  - Cloud Storage buckets
  - Filestore for shared cluster storage
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION_NAME`) for 2 `a4-highgpu-8g` VMs (16 NVIDIA B200 GPUs total) in your chosen region.
* A valid Hugging Face token (`HF_TOKEN`) with access to the `mistralai/Mixtral-8x7B-v0.1` model.
* The `gcloud`, `curl`, and `tar` CLI tools installed (`1_deploy_cluster.sh` downloads the Cluster Toolkit `gcluster` binary automatically).
* Identity and Access Management (IAM) permissions to create Compute Engine instances and firewall rules, Filestore instances, and Cloud Storage buckets.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `ZONE`, `RESERVATION_NAME`, and `HF_TOKEN` variables.
   
   ```bash
   source 0_env.sh
   ```

2. Run `./1_deploy_cluster.sh`:
   
   ```bash
   ./1_deploy_cluster.sh
   ```

3. Run `./2_run_job.sh`:
   
   ```bash
   ./2_run_job.sh
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
  
* [Use FSDP to fine-tune Mixtral-8x7B on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/fsdp-mixtral-8x7b)