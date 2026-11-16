# Pre-train Mixtral 8x7B on a multi-host A4 GKE cluster with Megatron-LM

This sample demonstrates how to provision a two-node A4 (`a4-highgpu-8g`, 16x
NVIDIA B200 GPUs) Google Kubernetes Engine (GKE) cluster with Cluster Toolkit,
tokenize an English shard from the public Colossal Clean Crawled Corpus
(`allenai/c4`) into Megatron-LM `IndexedDataset` format on Cloud Storage FUSE,
and run a distributed Mixtral 8x7B (`mistralai/Mixtral-8x7B-v0.1`) pre-training
JobSet with NVIDIA Megatron-LM (`Megatron-Core` `v0.14.0`).

The training JobSet uses 4D parallelism (`TP=2`, interleaved `PP=2` with virtual
pipeline stages, `EP=4`, `DP=4`), Transformer Engine FP8 `TEGroupedMLP` grouped
GEMMs, overlapped NCCL All-to-All and data-parallel collectives over fifth-gen
NVLink and GPUDirect RDMA (`NCCL_NET=gIB`), and asynchronous `torch_dist`
checkpoints persisted to Cloud Storage.

For the complete step-by-step walkthrough, see the official tutorial:
[Pre-train Mixtral 8x7B on a multi-host A4 GKE cluster with Megatron-LM](https://cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/pretrain-mixtral-8x7b-a4-gke-megatron).

## Scripts

Run the scripts in order after updating `0_env.sh` with your project, region,
zone, cluster name, Terraform state bucket name, and A4 reservation:

1. `source 0_env.sh` — Export environment variables for your deployment.
2. `./1_setup_cluster.sh` — Run pre-flight checks, install Cluster Toolkit
   `v1.103.0`, and deploy the two-node A4 GKE cluster.
3. `./2_prepare_dataset.sh` — Download the Mixtral 8x7B SentencePiece tokenizer
   and tokenize 100,000 C4 documents into `IndexedDataset` files on Cloud
   Storage FUSE.
4. `./3_train_model.sh` — Submit the 16-GPU Mixtral 8x7B Megatron-LM
   pre-training JobSet and wait for worker Pods to become ready.
5. `./4_validation.sh` — Wait for JobSet completion, summarize steady-state
   step latency, `TFLOP/s/GPU`, and `tokens/sec`, and verify saved `torch_dist`
   checkpoints in Cloud Storage.
6. `./cleanup.sh` — Delete workloads, empty the hierarchical-namespace buckets,
   destroy the Cluster Toolkit deployment, and remove the Terraform state
   bucket.
