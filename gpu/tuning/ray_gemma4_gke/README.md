# Fine-tune Gemma 4 E4B with Ray on an A4 GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 4 E4B vision-language model using Ray on a Google Kubernetes Engine (GKE) Autopilot cluster.

Note: This sample doesn’t demonstrate how to prepare a custom dataset or serve the model in production.

This sample provisions a GKE Autopilot cluster with the Ray operator enabled and deploys a Ray cluster across CPU and A4 GPU virtual machines (VMs). It runs distributed supervised fine-tuning (SFT) with quantized low-rank adaptation (QLoRA) and Transformer Reinforcement Learning (TRL) across 16 NVIDIA B200 GPUs, saving checkpoints to a Cloud Storage bucket. The sample includes the following files:

* `0_env.sh`: Configures starting environment variables, such as the project ID, region, cluster name, reservation, service accounts, Cloud Storage bucket, and Hugging Face token.
* `1_setup.sh`: Provisions the GKE Autopilot cluster with the Ray operator, creates the Hugging Face Kubernetes Secret and Cloud Storage bucket, and configures Workload Identity Federation for GKE.
* `2_deploy_model.sh`: Creates the training code ConfigMap, deploys the Ray cluster, and submits the fine-tuning `RayJob`.
* `*_validation.sh`: Waits for the training `RayJob` to succeed and submits a Ray job to validate that the fine-tuned adapter loads and generates a product description.
* `cleanup.sh`: Deletes the Ray resources, GKE cluster, Cloud Storage bucket, Identity and Access Management (IAM) service account, and persistent disks.
* `code/validate_adapter.py`: Downloads the fine-tuned low-rank adaptation (LoRA) adapter from Cloud Storage and runs an image-to-text generation check.
* `code/vision_train.py`: Runs distributed vision-language SFT on the `google/gemma-4-E4B-it` model using Ray Train, QLoRA, and TRL.
* `docs_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.
* `ray_cluster.yaml`: Configures the `RayCluster` custom resource with a CPU head pod and 2 `a4-highgpu-8g` worker pods.
* `ray_job.yaml`: Configures the `RayJob` custom resource and Python runtime environment for the fine-tuning job.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use Ray to fine-tune Gemma 4 for vision tasks on GKE](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/use-ray-fine-tune-gemma-vision-task-gke).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Autopilot cluster
  - Compute Engine A4 GPU VMs (`a4-highgpu-8g`) and CPU VMs
  - Cloud Storage bucket
  - Persistent disks

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION`) for 2 `a4-highgpu-8g` VMs (16 NVIDIA B200 GPUs across 2 nodes) in your chosen region.
* A valid Hugging Face token (`HF_TOKEN`) to download the `google/gemma-4-E4B-it` model.
* The `gcloud`, `kubectl`, and `envsubst` CLI tools installed.
* IAM permissions to create GKE clusters, create Cloud Storage buckets and bind bucket IAM policies (`roles/storage.admin`), and create IAM service accounts and bind service account IAM policies (`roles/iam.workloadIdentityUser`).

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `RESERVATION`, `REGION`, `CLUSTER_NAME`, `HF_TOKEN`, `RAY_SA`, `GSA_NAME`, and `GCS_BUCKET` variables, then source the file:

   ```bash
   source 0_env.sh
   ```

2. Provision the GKE Autopilot cluster, Cloud Storage bucket, and IAM configuration:

   ```bash
   ./1_setup.sh
   ```

3. Deploy the Ray cluster and submit the fine-tuning job:

   ```bash
   ./2_deploy_model.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to wait for the training job and verify the saved adapter:

   ```bash
   ./*_validation.sh
   ```

2. Verify that the output includes `VALIDATION PASSED: the fine-tuned adapter loads and generates a description.` and ends with `Validation succeeded`.

## Clean up

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```

## Additional resources

* [Use Ray to fine-tune Gemma 4 for vision tasks on GKE](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/use-ray-fine-tune-gemma-vision-task-gke)
