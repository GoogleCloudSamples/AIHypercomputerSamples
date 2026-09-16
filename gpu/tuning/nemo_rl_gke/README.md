# NeMo RL on GKE

This code sample is intended for AI/ML engineers and demonstrates how to run NeMo reinforcement learning by using a GKE cluster on Google Cloud.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_create_vpc_network.sh`: Creates the VPC network for the cluster.
* `2_create_cluster.sh`: Creates the GKE cluster.
* `3_prepare_storage.sh`: Prepares the required storage.
* `4_deploy_ray_cluster.sh`: Deploys a Ray cluster on GKE.
* `5_launch_job.sh`: Launches the reinforcement learning job.
* `6_monitor_job.sh`: Monitors the running job.
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

2. Run `./1_create_vpc_network.sh`:
   
   ```bash
   ./1_create_vpc_network.sh
   ```

3. Run `./2_create_cluster.sh`:
   
   ```bash
   ./2_create_cluster.sh
   ```

4. Run `./3_prepare_storage.sh`:
   
   ```bash
   ./3_prepare_storage.sh
   ```

5. Run `./4_deploy_ray_cluster.sh`:
   
   ```bash
   ./4_deploy_ray_cluster.sh
   ```

6. Run `./5_launch_job.sh`:
   
   ```bash
   ./5_launch_job.sh
   ```

7. Run `./6_monitor_job.sh`:
   
   ```bash
   ./6_monitor_job.sh
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