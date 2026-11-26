# Pre-train Qwen3-30B-A3B on an A4 GKE cluster

This code sample is intended for AI/ML engineers and demonstrates how to pre-train the Qwen3-30B-A3B Mixture-of-Experts (MoE) model from scratch on a multi-host A4 Google Kubernetes Engine (GKE) Standard cluster using Cluster Toolkit, NVIDIA NeMo, and Megatron-Bridge.

Note: This sample doesn't demonstrate fine-tuning, serving the model in a production environment, or configuring Virtual Private Cloud (VPC) networks manually outside Cluster Toolkit.

The scripts in this directory deploy the infrastructure and run the pre-training workload on AI Hypercomputer. The sample uses Cluster Toolkit (`gcluster` `v1.104.0`) to provision a 2-node `a4-highgpu-8g` GKE cluster (16 NVIDIA B200 GPUs) with GPUDirect RDMA (`gIB`), Kueue, JobSet, and Cloud Storage FUSE persistent volumes. It downloads the public `Qwen/Qwen3-30B-A3B` tokenizer, tokenizes 100,000 English documents from `allenai/c4` into Megatron `IndexedDataset` files, runs Megatron-Bridge's official B200 MXFP8 recipe (intra-node NVLink Expert Parallelism `EP=8` with `HybridEP` and `full_iteration` CUDA graphs, cross-node Data Parallelism `Dense DP=16` and `Expert DP=2` over gIB RDMA) for 50 iterations with mid-run asynchronous `torch_dist` checkpointing (`--save_interval 25`), and verifies clean checkpoint resumption through iteration 55. The sample includes the following files:

* `0_env.sh`: Configures the starting environment variables, such as the project ID, region, zone, cluster name, Terraform state bucket, and A4 reservation name.
* `1_setup_cluster.sh`: Downloads Cluster Toolkit, creates the Terraform state bucket, deploys the 2-node A4 GKE cluster, and verifies cluster add-ons and persistent volume claims.
* `2_prepare_data.sh`: Submits the Kubernetes Job that downloads the public tokenizer and tokenizes 100,000 C4 English documents onto Cloud Storage FUSE.
* `3_pretrain.sh`: Submits the 2-node Megatron-Bridge pre-training JobSet for 50 iterations with mid-run asynchronous checkpointing, captures Run 1 logs, and lists the saved checkpoints in Cloud Storage.
* `4_resume_training.sh`: Deletes the completed JobSet and relaunches it with `TRAIN_ITERS=55` to verify checkpoint loading from `iter_0000050` and continuation through iteration 55.
* `*_validation.sh`: Verifies the tokenized C4 dataset, mid-run and final Cloud Storage checkpoints, Run 1 loss convergence and asynchronous checkpoint overlap, and clean checkpoint resumption.
* `cleanup.sh`: Deletes the Kubernetes workloads, Cloud Storage FUSE dataset and checkpoint objects, the Cluster Toolkit GKE deployment, and the Terraform state bucket.
* `docs_snippets.sh`: Contains command snippets used only in the tutorial documentation for steps that differ from the automated scripts, including the optional NCCL RDMA bandwidth check and live log streaming.
* `metadata.yaml`: Defines sample metadata, such as the expected runtime for automated testing.
* `qwen3-data-prep.yaml`: Configures the Kubernetes Job that downloads the `Qwen/Qwen3-30B-A3B` tokenizer and tokenizes the `allenai/c4` shard.
* `qwen3-30b-a3b-pretrain-jobset.yaml`: Configures the 2-node Kueue-managed JobSet running `nvcr.io/nvidia/nemo:26.08.01` and Megatron-Bridge `scripts/performance/bootstrap.py`.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - GKE Standard cluster
  - Compute Engine virtual machines (VMs), including 2 `a4-highgpu-8g` GPU nodes (16 NVIDIA B200 GPUs total) and CPU system nodes
  - Cloud Storage buckets (for Terraform state, training data, and checkpoints using Cloud Storage FUSE)

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active 2-node `a4-highgpu-8g` (16 NVIDIA B200 GPUs) reservation (`RESERVATION_NAME`) in your target zone.
* Public internet access from the cluster nodes to pull the `nvcr.io/nvidia/nemo:26.08.01` container image, the public `Qwen/Qwen3-30B-A3B` tokenizer, and the public `allenai/c4` shard from Hugging Face. No Hugging Face token (`HF_TOKEN`) is required because the model is randomly initialized from scratch.
* The following CLI tools installed on your workstation: `gcloud`, `kubectl`, `gke-gcloud-auth-plugin`, `envsubst`, `curl`, `tar`, and `python3` (`1_setup_cluster.sh` downloads Cluster Toolkit `gcluster` and Terraform automatically using `--download-dependencies`).
* The following Google Cloud APIs enabled on your project: `compute.googleapis.com`, `container.googleapis.com`, `storage.googleapis.com`, `iam.googleapis.com`, `cloudresourcemanager.googleapis.com`, `serviceusage.googleapis.com`, `logging.googleapis.com`, and `monitoring.googleapis.com`.
* Identity and Access Management (IAM) roles granted to the user running Cluster Toolkit and `kubectl`:
  - Compute Admin (`roles/compute.admin`)
  - Kubernetes Engine Admin (`roles/container.admin`)
  - Storage Admin (`roles/storage.admin`)
  - Service Account Admin (`roles/iam.serviceAccountAdmin`)
  - Service Account User (`roles/iam.serviceAccountUser`)
  - Project IAM Admin (`roles/resourcemanager.projectIamAdmin`)
  - Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)

## Run the sample

To execute this sample, follow these steps:

1. Authenticate `gcloud` and Application Default Credentials:

   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. Open `0_env.sh`, replace the `YOUR_*` placeholders (`PROJECT_ID`, `REGION`, `ZONE`, `CLUSTER_NAME`, `BUCKET_NAME`, and `RESERVATION_NAME`), and source the script:

   ```bash
   source 0_env.sh
   ```

3. Deploy the 2-node A4 GKE cluster using Cluster Toolkit (~18-20 minutes):

   ```bash
   ./1_setup_cluster.sh
   ```

4. Prepare the tokenized C4 dataset and tokenizer on Cloud Storage FUSE (~2-4 minutes):

   ```bash
   ./2_prepare_data.sh
   ```

5. Run 50 pre-training iterations with mid-run asynchronous checkpointing at iteration 25 (~20-25 minutes):

   ```bash
   ./3_pretrain.sh
   ```

6. Verify clean checkpoint resumption from `iter_0000050` through iteration 55 (~20-25 minutes):

   ```bash
   ./4_resume_training.sh
   ```

## Verify the results

To verify that the pre-training workload and checkpoint resumption succeeded:

1. Run the validation script:

   ```bash
   ./*_validation.sh
   ```

2. Confirm the output reports all three verification stages passing:
   - `Verified iter_0000025: 16 .distcp shards present.` and `Verified iter_0000050: 16 .distcp shards present.`
   - `Verified latest_checkpointed_iteration.txt = 55.`
   - `Verified Run 1 loss convergence: iter 1 = ... -> iter 50 = ... (0 NaN/Inf across ... logged steps).`
   - `Verified resumed iterations 51-55: iter 51 = ... -> iter 55 = ... (0 NaN/Inf).`
   - `Validation passed: C4 dataset, mid-run async checkpointing (iter 25 & 50), loss convergence, and clean resume (iter 50 -> 55) all verified.`

## Clean up

To clean up the resources created by this sample, run the cleanup script:

```bash
./cleanup.sh
```

## Additional resources

* [AI Hypercomputer documentation](https://cloud.google.com/ai-hypercomputer/docs)
* [Deploy an A4 GKE cluster with Cluster Toolkit](https://cloud.google.com/cluster-toolkit/docs/deploy/gke/create-a4-cluster)
* [NVIDIA Megatron-Bridge on GitHub](https://github.com/NVIDIA-NeMo/Megatron-Bridge)
