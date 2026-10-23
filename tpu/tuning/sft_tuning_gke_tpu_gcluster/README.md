# SFT Tuning on a TPU GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to perform Supervised Fine-Tuning (SFT) on a Google Kubernetes Engine (GKE) cluster with TPUs, provisioned using Cluster Toolkit.

Note: This sample doesn't demonstrate how to prepare a dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_prerequisites.sh`: Installs prerequisites and Cluster Toolkit.
* `2_build_image.sh`: Builds the training container image.
* `3_setup_cluster.sh`: Deploys the GKE cluster.
* `4_convert_model.sh`: Converts the model format.
* `5_train_model.sh`: Submits the fine-tuning job.
* `6_convert_model_hf.sh`: Converts the trained model back to Hugging Face format.
* `cleanup.sh`: Terminates all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Run SFT for Gemma 4 31B on multi-host TPU v6e](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/run-gemma4-31b-sft-maxtext).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE
  - Compute Engine (TPUs)
  - Cloud Storage
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for the required TPUs in your chosen region.
  
* A valid Hugging Face token (`HF_TOKEN`) with access to the required model.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables.
   
   ```bash
   source 0_env.sh
   ```

2. Run the prerequisite script:
   
   ```bash
   ./1_prerequisites.sh
   ```

3. Build the image:
   
   ```bash
   ./2_build_image.sh
   ```

4. Deploy the cluster:
   
   ```bash
   ./3_setup_cluster.sh
   ```

5. Convert the model:
   
   ```bash
   ./4_convert_model.sh
   ```

6. Start the training job:
   
   ```bash
   ./5_train_model.sh
   ```

7. Convert the model back:
   
   ```bash
   ./6_convert_model_hf.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Check the status and logs of the training job:

   ```bash
   ./gcluster job list
   ./gcluster job logs sft --main-only -f
   ```

2. Verify that the coordinator logs output progress for each step (`completed step: <step>, seconds: ..., TFLOP/s/device: ..., loss: ...`) and `./gcluster job list` shows the status of `sft` as `Succeeded`.

3. Verify that the training checkpoints and converted Hugging Face model files are generated in your Cloud Storage bucket:

   ```bash
   gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/trained/sft/checkpoints/1000/model_params/"
   gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/hf-trained/"
   ```

## Clean up

To clean up the resources created by this sample:

1. Delete the GKE cluster with TPUs and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```

## Additional resources
  
* [Run SFT for Gemma 4 31B on multi-host TPU v6e](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/run-gemma4-31b-sft-maxtext)
