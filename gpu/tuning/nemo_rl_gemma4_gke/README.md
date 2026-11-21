# Fine-tune Gemma 4 12B with NeMo RL on a GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 4 12B model with NVIDIA NeMo reinforcement learning (RL) on a Google Kubernetes Engine (GKE) cluster.

Note: This sample doesn’t demonstrate how to prepare a custom dataset or serve the model in production.

This sample provisions a GKE Standard cluster with multi-networking across Google Virtual NIC (gVNIC) and Remote Direct Memory Access (RDMA) Virtual Private Cloud (VPC) networks, attaches a Google Cloud Managed Lustre filesystem for shared high-throughput checkpoint storage, and deploys a KubeRay cluster on GPU virtual machines (VMs) (`a4-highgpu-8g` or `a3-ultragpu-8g`). Inside the Ray cluster, NeMo RL runs distributed Group Relative Policy Optimization (GRPO) training on `google/gemma-4-12B-it`. The sample includes the following files:

* `0_env.sh`: Configures starting environment variables, such as the project ID, region, zones, cluster name, GPU and machine types, reservation, Managed Lustre name, network prefixes, and API tokens.
* `1_create_vpc_network.sh`: Creates the default cluster VPC network, the gVNIC VPC network and firewall rules, and the RDMA VPC network and subnets.
* `2_create_cluster.sh`: Provisions the GKE Standard cluster, creates the multi-NIC GPU node pool, installs the NCCL RDMA installer, and applies the network mapping.
* `3_prepare_storage.sh`: Configures private services access VPC peering, provisions a Managed Lustre instance, and creates the Kubernetes PersistentVolume and PersistentVolumeClaim.
* `4_deploy_ray_cluster.sh`: Clones the Helm chart repository and deploys the KubeRay cluster on GKE.
* `5_launch_job.sh`: Submits the NeMo RL GRPO training job inside the Ray head container and streams logs locally.
* `6_monitor_job.sh`: Inspects the training output and checkpoint directory inside the Ray head container.
* `*_validation.sh`: Validates that all training steps completed with a finite loss and verifies the saved policy checkpoint on the Managed Lustre volume.
* `cleanup.sh`: Deletes the Ray Helm release, GKE cluster, Managed Lustre instance, VPC peering, subnets, firewall rules, and VPC networks.
* `docs_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts.
* `lustre-pv.yaml`: Configures the Kubernetes PersistentVolume backed by the Managed Lustre instance.
* `lustre-pvc.yaml`: Configures the Kubernetes PersistentVolumeClaim requesting 18,000 GiB of Managed Lustre storage.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.
* `network-mapping.yaml`: Configures GKE `Network` and `GKENetworkParamSet` custom resources for the gVNIC and 8 RDMA interfaces.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: [Fine-tune and scale reinforcement learning with NVIDIA NeMo RL on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/nemo-rl-gke).

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Standard cluster
  - Compute Engine GPU VMs (`a4-highgpu-8g` or `a3-ultragpu-8g`) and CPU VMs (`n2-highmem-16`)
  - Managed Lustre (18,000 GiB) and Compute Engine persistent boot disks
  - VPC networks, subnets, and VPC peering resources

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active Compute Engine reservation (`RESERVATION`) for 2 `a4-highgpu-8g` VMs (16 NVIDIA B200 GPUs across 2 nodes) or 2 `a3-ultragpu-8g` VMs (16 NVIDIA H200 GPUs across 2 nodes) in `NODE_ZONE`, quota for `n2-highmem-16` CPU VMs in `CONTROL_PLANE_REGION`, and Managed Lustre capacity quota of at least 18,000 GiB in `LUSTRE_ZONE`.
* A valid Hugging Face token (`HF_TOKEN`) to download the `google/gemma-4-12B-it` model.
* A Weights & Biases API key (`WANDB_API_KEY`) for experiment metric logging.
* The `gcloud`, `kubectl`, `git`, `curl`, `tar`, and `envsubst` CLI tools installed (`4_deploy_ray_cluster.sh` installs `helm` and the `kubectl-ray` plugin automatically if not already present).
* Identity and Access Management (IAM) permissions to create VPC networks, subnets, firewall rules, and service networking VPC peerings, create GKE clusters and node pools, and create Managed Lustre instances.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update `PROJECT_ID`, `CONTROL_PLANE_REGION`, `NODE_ZONE`, `LUSTRE_ZONE`, `CLUSTER_NAME`, `GPU_TYPE`, `MACHINE_TYPE`, `RESERVATION`, `LUSTRE_NAME`, `HF_TOKEN`, `WANDB_API_KEY`, `NETWORK_PREFIX`, `GVNIC_NETWORK_PREFIX`, and `RDMA_NETWORK_PREFIX`, then source the file:

   ```bash
   source 0_env.sh
   ```

2. Create the default, gVNIC, and RDMA VPC networks and subnets:

   ```bash
   ./1_create_vpc_network.sh
   ```

3. Create the GKE Standard cluster, GPU node pool, and multi-network configuration:

   ```bash
   ./2_create_cluster.sh
   ```

4. Provision the Managed Lustre instance and bind the Kubernetes persistent volume:

   ```bash
   ./3_prepare_storage.sh
   ```

5. Deploy the KubeRay cluster using Helm:

   ```bash
   ./4_deploy_ray_cluster.sh
   ```

6. Launch the NeMo RL GRPO training job:

   ```bash
   ./5_launch_job.sh
   ```

7. Inspect the generated checkpoints and logs inside the Ray head pod:

   ```bash
   ./6_monitor_job.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to check the training logs and verify the checkpoint on Managed Lustre:

   ```bash
   ./*_validation.sh
   ```

2. Verify that the script reports the completed training steps, a finite training loss, and `Validation Succeeded!`.

## Clean up

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```

## Additional resources

* [Fine-tune and scale reinforcement learning with NVIDIA NeMo RL on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/nemo-rl-gke)
