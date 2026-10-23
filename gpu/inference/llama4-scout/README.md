# Serve Llama 4 Scout on a GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to serve the Llama 4 Scout model on a Google Kubernetes Engine (GKE) cluster for inference.

Note: This sample doesn’t demonstrate how to fine-tune the model or configure Virtual Private Cloud (VPC) networks from scratch.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The workload deploys a vLLM inference server on a GKE cluster equipped with NVIDIA GPUs, using Kubernetes configurations to provision the model and serve it using an exposed service. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup_cluster.sh`: Sets up the cluster.
* `2_deploy_model.sh`: Deploys the model.
* `*_validation.sh`: Validates the workload.
* `cleanup.sh`: Terminates all created resources.
* `docs_snippet.sh`: Contains documentation snippets.
* `vllm-l4-17b.yaml`: Configures the model.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use vLLM on GKE to run inference with Llama 4](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/vllm-gke-llama4).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Autopilot cluster
  - Compute Engine A4 VMs (`a4-highgpu-8g` with 8 NVIDIA B200 GPUs)
  - Network egress and load balancing
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION_NAME`) for A4 VMs (`a4-highgpu-8g`, 8 NVIDIA B200 GPUs per node) in your chosen region.
* An existing VPC network (`NETWORK`) and subnetwork (`SUBNETWORK`).
* A valid Hugging Face token (`HF_TOKEN`) with access to the `meta-llama/Llama-4-Scout-17B-16E-Instruct` model.
* The `gcloud`, `kubectl`, and `envsubst` CLI tools installed.
* Identity and Access Management (IAM) permissions to create and manage GKE clusters and Compute Engine resources.

## Run the sample

To execute this sample, follow these steps:

1. Update and source the environment variables:
   
   ```bash
   source 0_env.sh
   ```

2. Run the setup script:

   ```bash
   ./1_setup_cluster.sh
   ```

3. Deploy the model:

   ```bash
   ./2_deploy_model.sh
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
  
* [Use vLLM on GKE to run inference with Llama 4](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/vllm-gke-llama4)
