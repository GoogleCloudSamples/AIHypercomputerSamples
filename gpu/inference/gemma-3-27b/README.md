# Serve Gemma 3 27B on a GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to serve the Gemma 3 27B model on a Google Kubernetes Engine (GKE) cluster for inference.

Note: This sample doesn’t demonstrate how to fine-tune the model or configure VPC networks from scratch.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The workload deploys a vLLM inference server on a GKE cluster equipped with NVIDIA GPUs, using Kubernetes configurations to provision the model and serve it using an exposed service. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup.sh`: Sets up the cluster and infrastructure.
* `2_deploy_model.sh`: Deploys the model.
* `3_interract_with_model.sh`: Interacts with the deployed model.
* `*_validation.sh`: Validates the workload.
* `cleanup.sh`: Terminates all created resources.
* `docs_snippets.sh`: Contains documentation snippets.
* `vllm-3-27b-it.yaml`: Configures the model.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use vLLM on GKE to serve Gemma 3 27B inference](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-3-vllm-inference).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE clusters
  - Compute Engine instances with NVIDIA GPUs
  - Cloud Storage buckets (if used for model storage)
  - Network egress and load balancing
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Sufficient quota for NVIDIA GPUs (for example, 8 GPUs per node) and standard compute resources in your chosen region.
  
* A Hugging Face token (if the model requires authentication), the `gcloud` and `kubectl` CLI tools installed, and appropriate IAM permissions for GKE and Cloud Storage.

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

3. Deploy the model:

   ```bash
   ./2_deploy_model.sh
   ```

4. Interact with the model:

   ```bash
   ./3_interract_with_model.sh
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
  
* [Use vLLM on GKE to serve Gemma 3 27B inference](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-3-vllm-inference)
