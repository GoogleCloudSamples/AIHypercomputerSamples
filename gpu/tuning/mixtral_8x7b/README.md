# Fine-tune Mixtral 8x7B on a Slurm cluster

This code sample is intended for AI/ML engineers and demonstrates how to run Mixtral 8x7B fine-tuning using a Slurm cluster on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

This sample provisions a Slurm cluster using Cluster Toolkit. The architecture uses A4 High GPU (`a4-highgpu-8g`) instances for the compute nodes, a Cloud Storage bucket for storage, and Google Cloud Managed Lustre for shared cluster storage. Managed Lustre can be in a different zone than the compute nodes (set `LUSTRE_ZONE`), for example when Managed Lustre quota isn't available in the compute zone. The workload distributes fine-tuning across the GPUs using a Slurm `sbatch` script. The sample includes the following files:

* `0_env.sh`: Configures environment variables, including the project ID, zone, and Hugging Face token.
* `1_deploy_cluster.sh`: Uses Cluster Toolkit to deploy the Slurm cluster infrastructure and storage.
* `2_run_job.sh`: Submits the `sbatch` job to distribute the fine-tuning workload across the cluster.
* `env_setup.sbatch`: Slurm batch wrapper submitted by `2_run_job.sh` that runs `install_environment.sh` on node-local SSD and stores the environment and model on shared storage.
* `train.sbatch`: Slurm batch wrapper submitted by `2_run_job.sh` that stages the environment on node-local SSD and runs `train-mixtral.sh`.
* `*_validation.sh`: Validates that the fine-tuning workload ran successfully.
* `cleanup.sh`: Deletes the Slurm cluster and all associated resources.
* `doc_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use FSDP to fine-tune Mixtral-8x7B on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/fsdp-mixtral-8x7b).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Compute Engine A4 (`a4-highgpu-8g`) virtual machines (VMs)
  - Cloud Storage buckets
  - Google Cloud Managed Lustre for shared cluster storage
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION_NAME`) for 2 `a4-highgpu-8g` VMs (16 NVIDIA B200 GPUs total) in your chosen region.
* Managed Lustre quota for a 36,000 GiB instance in `LUSTRE_ZONE`.
* A valid Hugging Face token (`HF_TOKEN`) with access to the `mistralai/Mixtral-8x7B-v0.1` model.
* The `gcloud`, `curl`, and `tar` CLI tools installed (`1_deploy_cluster.sh` downloads the Cluster Toolkit `gcluster` binary automatically).
* Identity and Access Management (IAM) permissions to create Compute Engine instances and firewall rules, Managed Lustre instances, and Cloud Storage buckets.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `ZONE`, `LUSTRE_ZONE`, `RESERVATION_NAME`, and `HF_TOKEN` variables.

   Set `LUSTRE_ZONE` to the zone for the Managed Lustre instance. Use the same value as `ZONE` to keep storage next to the compute nodes, or a different zone if Managed Lustre quota isn't available in `ZONE`.
   
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

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```
  
## Additional resources
  
* [Use FSDP to fine-tune Mixtral-8x7B on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/fsdp-mixtral-8x7b)