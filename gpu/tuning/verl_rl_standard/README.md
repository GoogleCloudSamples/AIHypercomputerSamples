# vERL RL on GKE Standard

This code sample is intended for AI/ML engineers and demonstrates how to run vERL reinforcement learning using a Google Kubernetes Engine (GKE) Standard cluster.

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

## Architecture and Workload

This sample provisions a GKE Standard cluster to run a distributed reinforcement learning workload with vERL. The architecture utilizes GPU-enabled Virtual Machines (e.g., C2 Standard instances) and a Ray cluster running on top of GKE. It configures custom VPC networking and uses Google Cloud Storage for datasets and checkpoints.

The sample includes the following scripts:

* `0_env.sh`: Configures starting environment variables (project ID, zone, token).
* `1_setup_network.sh`: Provisions the custom VPC network and firewall rules.
* `2_setup_cluster.sh`: Creates the GKE Standard cluster with the required machine types and GPU accelerators.
* `3_setup_network_mappings.sh`: Configures the necessary networking mappings.
* `4_setup_storage.sh`: Configures storage such as GCS Fuse for the workload.
* `5_prepare_data.sh`: Prepares the training data.
* `6_deploy_workload.sh`: Deploys the Ray cluster and the vERL reinforcement learning job.
* `7_run_job.sh`: Triggers and monitors the execution of the training job.
* `cleanup.sh`: Deletes the GKE cluster, network resources, and all associated infrastructure.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Google Kubernetes Engine (GKE) cluster and GPU Virtual Machines (e.g., c2-standard-16)
  - VPC network, Cloud NAT, and IP addresses
  - Persistent disks and Google Cloud Storage buckets
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota for the required hardware in your chosen region.
* Specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools like cluster-toolkit or kubectl, depending on the environment.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the environment variables (e.g., `PROJECT_ID`, `ZONE`, and `HF_TOKEN`).
   
   ```bash
   source 0_env.sh
   ```

2. Run `./1_setup_network.sh`:
   
   ```bash
   ./1_setup_network.sh
   ```

3. Run `./2_setup_cluster.sh`:
   
   ```bash
   ./2_setup_cluster.sh
   ```

4. Run `./3_setup_network_mappings.sh`:
   
   ```bash
   ./3_setup_network_mappings.sh
   ```

5. Run `./4_setup_storage.sh`:
   
   ```bash
   ./4_setup_storage.sh
   ```

6. Run `./5_prepare_data.sh`:
   
   ```bash
   ./5_prepare_data.sh
   ```

7. Run `./6_deploy_workload.sh`:
   
   ```bash
   ./6_deploy_workload.sh
   ```

8. Run `./7_run_job.sh`:
   
   ```bash
   ./7_run_job.sh
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
  
* [Fine-tune and scale reinforcement learning with verl on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/scaling-rl-verl-gke)
