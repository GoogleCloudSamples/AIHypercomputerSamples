# Fine-tune Gemma 3 on a Slurm cluster

This code sample is intended for AI/ML engineers and demonstrates how to run Gemma 3 fine-tuning using a Slurm cluster on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

## Architecture and Workload

This sample uses the Google Cloud Cluster Toolkit to provision a Slurm cluster with A4 High GPU (a4-highgpu-8g) compute nodes. It uses a Google Cloud Storage bucket for dataset and model checkpoints, and Filestore for shared cluster storage. The workload is distributed using Accelerate and PyTorch FSDP via a Slurm `sbatch` job.

The sample includes the following scripts:

* `0_env.sh`: Configures environment variables such as the project ID, region, and Hugging Face token.
* `1_deploy_cluster.sh`: Uses the Google Cloud Cluster Toolkit to deploy the Slurm cluster, GCS bucket, and Filestore.
* `2_run_job.sh`: Submits the `sbatch` job to the Slurm cluster to execute the Gemma 3 fine-tuning workload.
* `cleanup.sh`: Terminates the cluster and cleans up all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Fine-tune Gemma 3 on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-3-slurm-cluster).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - A4 High GPU Virtual Machines (e.g., a4-highgpu-8g)
  - Google Cloud Storage buckets
  - Filestore for shared cluster storage
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for the required hardware in your chosen region.
* Specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools like cluster-toolkit or kubectl, depending on the environment.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables (e.g., `PROJECT_ID`, `ZONE`, and `HF_TOKEN`).
   
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
  
* [Fine-tune Gemma 3 on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-3-slurm-cluster)
