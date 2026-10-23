# Fine-tune Gemma 4 26B on a TPU GKE Cluster

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 4 26B model on a Google Kubernetes Engine (GKE) cluster with Cloud TPUs.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample uses Cluster Toolkit to provision a GKE cluster with a v6e-64 TPU node pool and a c4d-standard-96 CPU node pool. It converts the model format, runs the supervised fine-tuning workload using MaxText, and converts the trained model back to Hugging Face format. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_prerequisites.sh`: Installs required prerequisites.
* `2_build_image.sh`: Builds the required Docker image.
* `3_setup_cluster.sh`: Sets up the GKE cluster.
* `4_convert_model.sh`: Converts the model to the required format.
* `5_train_model.sh`: Submits the fine-tuning workload.
* `6_convert_model_hf.sh`: Converts the model back to Hugging Face format.
* `cleanup.sh`: Terminates all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Run multi-host reinforcement learning training for Gemma 4 26B on TPU v6e](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/run-gemma4-26b-rl-maxtext).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE cluster
  - Compute Engine (Cloud TPU v6e-64 and CPU c4d-standard-96 node pools)
  - Cloud Storage
  - Artifact Registry

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active reservation (`RESERVATION`) for Cloud TPU `v6e-64` (64 TPU v6e chips) and `c4d-standard-96` CPU VMs in your chosen zone.
* A valid Hugging Face token (`HF_TOKEN`) with access to the `google/gemma-4-26b-a4b-it` model.
* The `gcloud`, `kubectl`, `docker`, `wget`, and `tar` CLI tools installed (`1_prerequisites.sh` downloads the Cluster Toolkit `gcluster` binary automatically).
* Identity and Access Management (IAM) permissions to enable Google Cloud APIs, create GKE clusters, create Cloud Storage buckets, and bind project IAM roles (`roles/storage.admin`, `roles/storage.objectViewer`, `roles/logging.logWriter`, and `roles/artifactregistry.writer`).

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables.
   
   ```bash
   source 0_env.sh
   ```

2. Install prerequisites.
   ```bash
   ./1_prerequisites.sh
   ```

3. Build the required Docker image.
   ```bash
   ./2_build_image.sh
   ```

4. Set up the GKE cluster.
   ```bash
   ./3_setup_cluster.sh
   ```

5. Convert the model.
   ```bash
   ./4_convert_model.sh
   ```

6. Train the model.
   ```bash
   ./5_train_model.sh
   ```

7. Convert the trained model to Hugging Face format.
   ```bash
   ./6_convert_model_hf.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Check the status and logs of the training job:

   ```bash
   ./gcluster job list
   kubectl logs -f -l job-name=gemma4-training-pathways-head-0 -c workload-container
   ```

2. Verify that the logs output `Post RL Training: ... mean_reward=...` and `./gcluster job list` shows the status of `gemma4-training` as `Succeeded`.

3. Verify that the training checkpoints and converted Hugging Face model files are generated in your Cloud Storage bucket:

   ```bash
   gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/trained/rl/checkpoints/actor/"
   gcloud storage ls "gs://${GCS_BUCKET}/${MODEL_NAME}/hf-trained/"
   ```

## Clean up

To clean up the resources created by this sample:

1. Terminate the resources and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* [Run multi-host reinforcement learning training for Gemma 4 26B on TPU v6e](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/tpu/run-gemma4-26b-rl-maxtext)
