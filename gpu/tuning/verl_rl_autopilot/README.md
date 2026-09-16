# vERL RL on GKE Autopilot

This code sample is intended for AI/ML engineers and demonstrates how to run vERL reinforcement learning by using a GKE Autopilot cluster on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup_cluster.sh`: Sets up the GKE Autopilot cluster.
* `2_setup_storage.sh`: Sets up the required storage.
* `3_setup_dranet.sh`: Sets up DraNet.
* `4_prepare_data.sh`: Prepares the data for training.
* `5_deploy_workload.sh`: Deploys the workload.
* `6_run_job.sh`: Runs the reinforcement learning job.
* `cleanup.sh`: Terminates all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Virtual Machines (VMs)
  - Storage disks
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for the required hardware in your chosen region.
* Specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools like cluster-toolkit or kubectl, depending on the environment.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables (e.g., `PROJECT_ID`, `ZONE`, and `HF_TOKEN`).
   
   ```bash
   source 0_env.sh
   ```

2. Run `./1_setup_cluster.sh`:
   
   ```bash
   ./1_setup_cluster.sh
   ```

3. Run `./2_setup_storage.sh`:
   
   ```bash
   ./2_setup_storage.sh
   ```

4. Run `./3_setup_dranet.sh`:
   
   ```bash
   ./3_setup_dranet.sh
   ```

5. Run `./4_prepare_data.sh`:
   
   ```bash
   ./4_prepare_data.sh
   ```

6. Run `./5_deploy_workload.sh`:
   
   ```bash
   ./5_deploy_workload.sh
   ```

7. Run `./6_run_job.sh`:
   
   ```bash
   ./6_run_job.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to check the output logs:

   ```bash
   ./*_validation.sh
   ```

2. You should see an output indicating validation passed.

## Clean up

To clean up the resources created by this sample:

1. Terminate the cluster and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
