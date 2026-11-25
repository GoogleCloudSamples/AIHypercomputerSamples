# Fine-tune Gemma 4 E4B on Cloud TPU v6e

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 4 E4B model using supervised fine-tuning (SFT) with MaxText on Cloud TPU v6e.

Note: This sample doesn’t demonstrate how to prepare a custom dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample provisions a single-host Cloud TPU `v6e-8` virtual machine (VM) (`ct6e-standard-8t`), configures SSH access through Identity-Aware Proxy (IAP), converts the `google/gemma-4-E4B-it` checkpoint to MaxText format, runs SFT directly on the TPU VM, and exports the fine-tuned weights back to Hugging Face format. The sample includes the following files:

* `0_env.sh`: Configures starting environment variables, such as the project ID, zone, reservation, TPU instance name, and Hugging Face token.
* `1_setup.sh`: Provisions the Cloud TPU `v6e-8` VM instance and waits for it to reach the `RUNNING` state.
* `2_run_script.sh`: Creates the IAP SSH firewall rule, copies `run_on_vm.sh` to the TPU VM, and runs the fine-tuning workflow.
* `*_validation.sh`: Connects to the TPU VM over SSH to verify the training logs, MaxText checkpoint, and exported Hugging Face `.safetensors` model.
* `cleanup.sh`: Deletes the Cloud TPU VM instance and the IAP firewall rule.
* `docs_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.
* `run_on_vm.sh`: Installs MaxText on the TPU VM, converts the model checkpoint, runs SFT, and exports the trained model to Hugging Face format.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Run supervised fine-tuning on a TPU VM by using MaxText](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/run-sft-v6e-8-tpu-vm-maxtext).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Cloud TPU (`ct6e-standard-8t` `v6e-8` TPU VM)
  - Compute Engine persistent boot disk (`200GB`)

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active reservation (`RESERVATION`) for Cloud TPU `v6e-8` (`ct6e-standard-8t`, 8 TPU v6e chips) in your chosen zone.
* An existing Virtual Private Cloud (VPC) network (`NETWORK`, set to `default` by default).
* A valid Hugging Face token (`HF_TOKEN`) to download the `google/gemma-4-E4B-it` model.
* The `gcloud` CLI tool installed.
* Identity and Access Management (IAM) permissions to create and delete Compute Engine TPU VM instances and firewall rules, and connect to instances using SSH through IAP.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `PROJECT_ID`, `ZONE`, `RESERVATION`, `TPU_NAME`, and `HF_TOKEN` variables, then source the file:

   ```bash
   source 0_env.sh
   ```

2. Provision the Cloud TPU `v6e-8` VM:

   ```bash
   ./1_setup.sh
   ```

3. Configure SSH access and run the MaxText SFT workflow on the TPU VM:

   ```bash
   ./2_run_script.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to inspect the logs, training checkpoint, and exported Hugging Face model on the TPU VM:

   ```bash
   ./*_validation.sh
   ```

2. Verify that the output reports the exported tensor and shard counts and ends with `== [Validation] SUCCESS: SFT finished and the Hugging Face export is complete. ==`.

## Clean up

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```

## Additional resources

* [Run supervised fine-tuning on a TPU VM by using MaxText](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/run-sft-v6e-8-tpu-vm-maxtext)
