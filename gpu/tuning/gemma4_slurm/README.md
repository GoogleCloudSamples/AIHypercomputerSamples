# Fine-tune Gemma 4 31B on an A4 Slurm cluster

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 4 31B model using a Slurm cluster deployed on A4 virtual machines (VMs) on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

This sample uses Cluster Toolkit to provision a Slurm cluster with A4 High GPU (`a4-highgpu-8g`) compute nodes, Google Cloud Managed Lustre for shared cluster storage, and Cloud Storage buckets for Terraform state and deployment artifacts. The workload runs supervised fine-tuning (SFT) with low-rank adaptation (LoRA), distributed across the nodes with Accelerate and PyTorch Fully Sharded Data Parallel (FSDP) using a Slurm `sbatch` job. The sample includes the following files:

* `0_env.sh`: Configures starting environment variables, such as the project ID, region, zone, reservation name, cluster name, bucket name, and Hugging Face token.
* `1_deploy_cluster.sh`: Creates the Cloud Storage bucket and uses Cluster Toolkit to deploy the Slurm cluster and Managed Lustre storage.
* `2_run_job.sh`: Uploads the workload files to the Slurm login node, sets up the Python virtual environment, submits the `sbatch` job, and monitors it to completion.
* `*_validation.sh`: Fetches the Slurm job logs and validates that the job completed and saved the LoRA language model adapter tensors.
* `accelerate_config.yaml`: Configures Accelerate and FSDP for multi-node distributed training across 16 GPUs.
* `cleanup.sh`: Destroys the Slurm cluster and deletes all created cloud and local resources.
* `docs_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts.
* `install_environment.sh`: Creates the shared Python virtual environment and installs PyTorch and fine-tuning dependencies on the login node.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.
* `requirements.txt`: Lists the Python package dependencies installed in the training environment.
* `submit.slurm`: Configures and runs the multi-node Slurm batch job that stages weights on local SSDs and launches `train.py`.
* `train.py`: Runs the LoRA SFT workload on the `google/gemma-4-31B-it` model.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Fine-tune Gemma 4 on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-4-slurm-cluster).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Compute Engine A4 (`a4-highgpu-8g`) GPU VMs and Slurm controller and login CPU VMs
  - Managed Lustre for shared cluster storage
  - Cloud Storage buckets
  - Virtual Private Cloud (VPC) networks, Cloud Router, and Cloud NAT

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION_URL`) for 2 `a4-highgpu-8g` VMs (16 NVIDIA B200 GPUs across 2 nodes) in your chosen zone, as well as Managed Lustre capacity quota in the same zone.
* A valid Hugging Face token (`HF_TOKEN`) to download the `google/gemma-4-31B-it` model.
* The `gcloud`, `curl`, `tar`, and `python3` CLI tools installed (`1_deploy_cluster.sh` downloads `terraform` and the Cluster Toolkit `gcluster` binary automatically).
* Identity and Access Management (IAM) permissions to create Compute Engine instances, instance templates, and firewall rules, create VPC networks and service networking peerings, create Managed Lustre instances, create Cloud Storage buckets, and connect to VMs using SSH through Identity-Aware Proxy (IAP).

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `ZONE`, `REGION`, `RESERVATION_URL`, `CLUSTER_NAME`, `BUCKET_NAME`, and `HF_TOKEN` variables, then source the file:

   ```bash
   source 0_env.sh
   ```

2. Deploy the Slurm cluster and supporting infrastructure:

   ```bash
   ./1_deploy_cluster.sh
   ```

3. Upload the training scripts, configure the Python environment, and run the Slurm fine-tuning job:

   ```bash
   ./2_run_job.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to inspect the Slurm job logs and verify the saved LoRA adapter:

   ```bash
   ./*_validation.sh
   ```

2. Verify that the output includes `Training finished.`, reports a non-zero count of `lora_tensors`, and outputs `Validation passed` followed by `Validation Complete.` upon completion.

## Clean up

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```

## Additional resources

* [Fine-tune Gemma 4 on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-4-slurm-cluster)
