# _TUTORIAL_TITLE_
# Run inference with Qwen2 7B Instruct on TPU v6e

This code sample is intended for AI/ML engineers and demonstrates how to run inference and benchmark workloads with the Qwen2 7B Instruct model on Google Cloud TPUs (v6e).

Note: This sample doesn’t demonstrate how to serve the model in production or configure VPC networks from scratch.

## Architecture

The sample provisions a single Cloud TPU v6e-8 using a TPU VM architecture. The inference and benchmark scripts execute directly on the provisioned TPU VM.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables, such as the project ID, zone, and Hugging Face token.
* `1_setup.sh`: Sets up the required infrastructure and environment.
* `2_run_inference.sh`: Runs the inference workload on the TPU.
* `3_run_benchmark.sh`: Runs the benchmark workload.
* `*_validation.sh`: Validates the workload ran successfully.
* `cleanup.sh`: Terminates all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Compute Engine (Cloud TPU v6e-8 via TPU VM)
  - Cloud Storage

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for TPUs in your chosen region.
* A valid Hugging Face token (HF_TOKEN) with access to the model, and necessary IAM permissions.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables.
   
   ```bash
   source 0_env.sh
   ```

2. Run the setup script.
   ```bash
   ./1_setup.sh
   ```

3. Run the inference script.
   ```bash
   ./2_run_inference.sh
   ```

4. Run the benchmark script.
   ```bash
   ./3_run_benchmark.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to check the output logs:

   ```bash
   ./*_validation.sh
   ```

2. You should see an output indicating success and the expected inference/benchmark results.

## Clean up

To clean up the resources created by this sample:

1. Terminate the resources and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* [Serve Qwen2-7B with vLLM on TPUs](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/serve-qwen2-7b-vllm)
* [Serve Qwen2-7B-Instruct with vLLM on TPUs](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/serve-qwen2-7b-instruct)
* [Run vLLM with Qwen3-8B-Base](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/serve-qwen3-8b-base)
* [Serve Llama-3.1-8B with vLLM on TPUs](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/serve-llama-3.1-8b)