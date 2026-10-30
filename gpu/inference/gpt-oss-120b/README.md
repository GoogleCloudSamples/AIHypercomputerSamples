# Serve GPT-OSS 120B on a GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to serve the GPT-OSS 120B model on a Google Kubernetes Engine (GKE) cluster for inference.

Note: This sample doesn’t demonstrate how to fine-tune the model or configure Virtual Private Cloud (VPC) networks from scratch.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The workload deploys a vLLM inference server on a GKE cluster equipped with NVIDIA GPUs, using Kubernetes configurations to provision the model and serve it using an exposed service. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup.sh`: Sets up the cluster and infrastructure.
* `2_download_model.sh`: Downloads the model.
* `3_deploy_model.sh`: Deploys the model.
* `4_interract_with_model.sh`: Interacts with the deployed model.
* `*_validation.sh`: Validates the workload.
* `cleanup.sh`: Terminates all created resources.
* `docs_snippets.sh`: Contains documentation snippets.
* `gpt-download-job.yaml`: Configures the job.
* `vllm-gpt-oss-120b.yaml`: Configures the model.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use vLLM on GKE to run inference with gpt-oss-120b](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gpt-oss-vllm-inference).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Autopilot cluster
  - Compute Engine A4 Virtual Machines (VMs) (`a4-highgpu-8g` with 8 NVIDIA B200 GPUs)
  - Cloud Storage bucket
  - Network egress and load balancing
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION_URL`) for A4 VMs (`a4-highgpu-8g`, 8 NVIDIA B200 GPUs per node) in your chosen region.
* An existing VPC network (`NETWORK`) and subnetwork (`SUBNETWORK`).
* A valid Hugging Face token (`HUGGING_FACE_TOKEN`) with access to the `openai/gpt-oss-120b` model.
* The `gcloud`, `kubectl`, and `envsubst` CLI tools installed.
* Identity and Access Management (IAM) permissions to create GKE clusters, create Cloud Storage buckets, and manage bucket IAM policy bindings (`roles/storage.objectAdmin`).

## Run the sample

To execute this sample, follow these steps:

1. Update and source the environment variables:
   
   ```bash
   source 0_env.sh
   ```

2. Run the setup script:

   ```bash
   ./1_setup.sh
   ```

3. Download the model:

   ```bash
   ./2_download_model.sh
   ```

4. Deploy the model:

   ```bash
   ./3_deploy_model.sh
   ```

5. Interact with the model:

   ```bash
   ./4_interract_with_model.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Check the logs and validate the output:

   ```bash
   ./*_validation.sh
   ```

2. You should see successful inference responses in the validation logs.

## Clean up

To clean up the resources created by this sample:

1. Delete resources:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* [Use vLLM on GKE to run inference with gpt-oss-120b](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gpt-oss-vllm-inference)
