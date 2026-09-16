# _TUTORIAL_TITLE_
# Example: Fine-tune Gemma 3 4B (SFT) on TPU

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 3 4B model using Supervised Fine-Tuning (SFT) on TPUs on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup.sh`: Sets up the required infrastructure and environment.
* `2_run_script.sh`: Submits the fine-tuning workload.
* `*_validation.sh`: Validates the workload ran successfully.
* `cleanup.sh`: Terminates all created resources.
* `run_on_vm.sh`: Script to run the workload on a VM.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - TPUs and Storage.
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for TPUs in your chosen region.
* A valid Hugging Face token (HF_TOKEN) with access to the Gemma 3 model, and necessary IAM permissions.

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

3. Run the script to start the fine-tuning.
   ```bash
   ./2_run_script.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to check the output logs:

   ```bash
   ./*_validation.sh
   ```

2. You should see an output indicating success and the final training loss.

## Clean up

To clean up the resources created by this sample:

1. Terminate the resources and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
