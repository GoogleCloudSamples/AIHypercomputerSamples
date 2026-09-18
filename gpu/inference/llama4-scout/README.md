# Serve Llama 4 Scout on a GKE cluster

This sample provides a set of scripts to serve the Llama 4 Scout model on Google Kubernetes Engine (GKE) for inference. It is intended for machine learning engineers and developers looking to deploy large language models on Google Cloud.

The workload deploys a vLLM inference server on a GKE cluster equipped with NVIDIA GPUs. The deployment uses Kubernetes configurations to provision the model and serve it via an exposed service.

The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup_cluster.sh`: Sets up the cluster.
* `2_deploy_model.sh`: Deploys the model.
* `*_validation.sh`: Validates the workload.
* `cleanup.sh`: Terminates all created resources.
* `docs_snippet.sh`: Documentation snippets.
* `vllm-l4-17b.yaml`: Model configuration.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE clusters
  - Compute Engine instances with NVIDIA GPUs
  - Google Cloud Storage buckets (if used for model storage)
  - Network egress and load balancing
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Sufficient quota for NVIDIA GPUs (e.g., 8 GPUs per node) and standard compute resources in your chosen region.
  
* A Hugging Face token (if the model requires authentication), the gcloud and kubectl CLI tools installed, and appropriate IAM permissions for GKE and GCS.

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
