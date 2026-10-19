# Serve Qwen3-Coder-480B on a multi-host GKE TPU v7x cluster

This code sample is intended for AI/ML engineers and platform administrators and demonstrates how to serve the `Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8` Mixture-of-Experts (MoE) model on a multi-host Google Kubernetes Engine (GKE) Standard cluster with Ironwood (TPU v7x) using SGLang-TorchTPU and Prefill/Decode (PD) disaggregation.

Note: This sample doesn't demonstrate how to fine-tune the model, configure custom VPC networks from scratch, or set up production ingress, authentication, and autoscaling.

The scripts in this directory provision a GKE cluster with two multi-host TPU v7x node pools (each using a `2x2x2` topology with 2 nodes, 8 TPU chips, and 16 TensorCores), install the Kubernetes LeaderWorkerSet (LWS) controller, and deploy disaggregated SGLang prefill and decode pools behind an SGLang router. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables, including the project ID, region, zone, cluster name, reservation name, Hugging Face token, and SGLang-TorchTPU container image.
* `1_setup.sh`: Creates the GKE Standard cluster, the `2x2x2` compact workload placement policy, two 2-node `tpu7x-standard-4t` node pools (`tpu7x-pool-0` and `tpu7x-pool-1`), the Hugging Face Kubernetes secret, and installs the LeaderWorkerSet (LWS) controller.
* `qwen3-coder-480b-multihost-disagg-v7x.yaml`: Defines the Kubernetes manifests for the `hyperdisk-balanced-tpu` StorageClass, the multi-host `sglang-tpu-prefill` and `sglang-tpu-decode` LeaderWorkerSets (`size: 2`, `tp=16`, `ep=16`), the `sglang-router` Deployment, and their corresponding ClusterIP Services.
* `2_run_inference.sh`: Substitutes the container image into `qwen3-coder-480b-multihost-disagg-v7x.yaml`, applies the manifest to the cluster, and waits for the prefill, decode, and router workloads to become available.
* `*_validation.sh`: Forwards port `8000` from `sglang-service` and sends a test OpenAI-compatible `/v1/chat/completions` request to verify that the model is serving traffic.
* `3_run_benchmark.sh`: Runs the `sglang.bench_serving` benchmark inside the `sglang-router` pod (`256` random prompts, `1024` input and `1024` output tokens, concurrency `64`).
* `docs_snippets.sh`: Contains supplementary command snippets referenced in the documentation for downloading the manifest, streaming leader pod logs, and manual port-forwarding.
* `cleanup.sh`: Terminates all created Kubernetes workloads, TPU node pools, the GKE cluster, and the workload placement policy.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - Google Kubernetes Engine (GKE) cluster management and `e2-standard-4` default node pool VMs
  - Compute Engine Ironwood TPU v7x VMs (4 `tpu7x-standard-4t` nodes across two `2x2x2` node pools, totaling 16 TPU v7x chips)
  - Compute Engine Hyperdisk Balanced volumes (4 ephemeral `700Gi` `hyperdisk-balanced` disks for model weight caching)

  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* Quota and an active reservation for at least 4 `tpu7x-standard-4t` VMs (16 TPU v7x chips across two `2x2x2` slices) in your chosen zone.
* A valid Hugging Face token (`HF_TOKEN`) with access to the `Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8` model, an SGLang-TorchTPU container image URI (`SGLANG_IMAGE`), and the `gcloud`, `kubectl`, and `envsubst` CLI tools installed on your local machine.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the `CLUSTER_NAME`, `PROJECT_ID`, `REGION`, `ZONE`, `RESERVATION`, `HF_TOKEN`, and `SGLANG_IMAGE` variables, then source the file:

   ```bash
   source 0_env.sh
   ```

2. Provision the GKE cluster, workload placement policy, TPU v7x node pools, Hugging Face secret, and LeaderWorkerSet controller:

   ```bash
   ./1_setup.sh
   ```

3. Deploy the disaggregated SGLang prefill and decode pools and router, and wait for all workloads to become available:

   ```bash
   ./2_run_inference.sh
   ```

4. (Optional) Run the serving throughput and latency benchmark:

   ```bash
   ./3_run_benchmark.sh
   ```

## Verify the results

To verify that the workload ran successfully:

1. Run the validation script to forward the router service port and send a test chat completion request:

   ```bash
   ./*_validation.sh
   ```

2. You should see a JSON `chat.completion` response from `Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8` containing a two-sentence explanation of the quicksort algorithm. If you also ran `./3_run_benchmark.sh`, you should see the `Serving Benchmark Result` summary with `Successful requests: 256` along with token throughput, TTFT, and TPOT metrics.

## Clean up

To clean up the resources created by this sample:

1. Delete the deployed Kubernetes workloads, TPU v7x node pools, GKE cluster, and workload placement policy:

   ```bash
   ./cleanup.sh
   ```

## Additional resources

* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
* [TPUs in GKE documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/tpus)
* [LeaderWorkerSet (LWS) documentation](https://lws.sigs.k8s.io/)
