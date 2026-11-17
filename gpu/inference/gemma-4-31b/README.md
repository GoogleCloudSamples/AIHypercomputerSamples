# Serve Gemma 4 31B on an A4 GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to serve the Gemma 4 31B model on a Google Kubernetes Engine (GKE) Autopilot cluster deployed on A4 virtual machines (VMs) for inference.

Note: This sample doesn’t demonstrate how to fine-tune the model or configure Virtual Private Cloud (VPC) networks from scratch.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The workload deploys a vLLM inference server on a GKE Autopilot cluster equipped with 8 NVIDIA B200 GPUs on an A4 node, exposes it inside the cluster through a Kubernetes Service, and sends chat completion requests to its OpenAI-compatible endpoint. The sample includes the following files:

* `0_env.sh`: Configures starting environment variables, such as the project ID, region, cluster name, reservation name, network, and Hugging Face token.
* `1_setup.sh`: Provisions the GKE Autopilot cluster, fetches cluster credentials, and creates the Kubernetes Secret for the Hugging Face token.
* `2_deploy_model.sh`: Substitutes environment variables into the Kubernetes manifest, deploys the vLLM server, and waits for the Deployment to become available.
* `3_interact_with_model.sh`: Forwards a local port to the Kubernetes Service and sends a sample chat completion request to the deployed model.
* `*_validation.sh`: Validates that the vLLM server is healthy, serves the expected model, and returns a valid chat completion response.
* `cleanup.sh`: Deletes the Kubernetes resources and the GKE Autopilot cluster.
* `docs_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.
* `vllm-gemma-4-31b-it.yaml`: Configures the Kubernetes Deployment and Service for serving the Gemma 4 31B model with vLLM.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Use vLLM on GKE to serve Gemma 4 31B inference](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-4-vllm-inference).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Autopilot cluster
  - Compute Engine A4 VMs (`a4-highgpu-8g` with 8 NVIDIA B200 GPUs)
  - Network egress

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION_NAME`) for 1 A4 VM (`a4-highgpu-8g`, 8 NVIDIA B200 GPUs per node) in your chosen region.
* An existing VPC network (`NETWORK`) and subnetwork (`SUBNETWORK`).
* A valid Hugging Face token (`HUGGING_FACE_TOKEN`) to download the `google/gemma-4-31B-it` model.
* The `gcloud`, `kubectl`, `envsubst`, `curl`, and `jq` CLI tools installed.
* Identity and Access Management (IAM) permissions to create and manage GKE clusters and Compute Engine resources.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `REGION`, `CLUSTER_NAME`, `HUGGING_FACE_TOKEN`, `RESERVATION_NAME`, `NETWORK`, and `SUBNETWORK` variables, then source the file:

   ```bash
   source 0_env.sh
   ```

2. Create the GKE Autopilot cluster and configure the Hugging Face token Secret:

   ```bash
   ./1_setup.sh
   ```

3. Deploy the vLLM inference server:

   ```bash
   ./2_deploy_model.sh
   ```

4. Send a sample chat completion request to the model:

   ```bash
   ./3_interact_with_model.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to verify the model endpoint and chat completion output:

   ```bash
   ./*_validation.sh
   ```

2. Verify that the script prints the generated text response and outputs `Validation succeeded.` upon completion.

## Clean up

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```

## Additional resources

* [Use vLLM on GKE to serve Gemma 4 31B inference](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-4-vllm-inference)
