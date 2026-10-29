# Serve Qwen 3 Coder on a multi-host GKE TPU cluster (v7x or v6e)

This code sample is intended for AI/ML engineers and platform administrators and demonstrates how to serve the `Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8` or `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8` Mixture-of-Experts (MoE) models on a multi-host Google Kubernetes Engine (GKE) Standard cluster with Ironwood (TPU v7x) or Trillium (TPU v6e) using SGLang-TorchTPU and Prefill/Decode (PD) disaggregation.

Note: This sample doesn't demonstrate how to fine-tune the model, configure custom VPC networks from scratch, or set up production ingress, authentication, and autoscaling.

The scripts in this directory provision a GKE cluster with two multi-host TPU node pools, install the Kubernetes LeaderWorkerSet (LWS) controller, and deploy disaggregated SGLang prefill and decode pools behind an SGLang router. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables, including the project ID, region, zone, cluster name, reservation name, Hugging Face token, SGLang-TorchTPU container image, and `ACCELERATOR_TYPE`.
* `1_setup.sh`: Creates the GKE Standard cluster, the workload placement policy (for v7x only), two 2-node TPU node pools, the Hugging Face Kubernetes secret, and installs the LeaderWorkerSet (LWS) controller.
* `qwen3-coder-480b-multihost-disagg-v7x.yaml` and `qwen3-coder-30b-multihost-disagg-v6e-2x4.yaml`: Defines the Kubernetes manifests for the `hyperdisk-balanced-tpu` StorageClass, the multi-host `sglang-tpu-prefill` and `sglang-tpu-decode` LeaderWorkerSets, the `sglang-router` Deployment, and their corresponding ClusterIP Services.
* `2_run_inference.sh`: Substitutes the container image into the selected YAML manifest, applies it to the cluster, and waits for the prefill, decode, and router workloads to become available.
* `*_validation.sh`: Forwards port `8000` from `sglang-service` and sends a test OpenAI-compatible `/v1/chat/completions` request to verify that the model is serving traffic.
* `3_run_benchmark.sh`: Runs the `sglang.bench_serving` benchmark inside the `sglang-router` pod.
* `docs_snippets.sh`: Contains supplementary command snippets referenced in the documentation for downloading the manifest, streaming leader pod logs, and manual port-forwarding.
* `cleanup.sh`: Terminates all created Kubernetes workloads, TPU node pools, the GKE cluster, and the workload placement policy.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled.
* Quota and an active reservation for either:
  - 4 `tpu7x-standard-4t` VMs (16 TPU v7x chips) for Ironwood (`v7x`).
  - 4 `ct6e-standard-4t` VMs (16 TPU v6e chips) for Trillium (`v6e`).
* A valid Hugging Face token (`HF_TOKEN`) with access to the Qwen3-Coder models, an SGLang-TorchTPU container image URI (`SGLANG_IMAGE`), and the `gcloud`, `kubectl`, and `envsubst` CLI tools installed on your local machine.

## Run the sample

To execute this sample, follow these steps:

1. Open `0_env.sh` and update the variables including `ACCELERATOR_TYPE` (set to `v7x` or `v6e`), then source the file:

   ```bash
   source 0_env.sh
   ```

2. Provision the GKE cluster, node pools, Hugging Face secret, and LeaderWorkerSet controller:

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

2. You should see a JSON `chat.completion` response. If you also ran `./3_run_benchmark.sh`, you should see the `Serving Benchmark Result` summary.

## Clean up

To clean up the resources created by this sample:

1. Delete the deployed Kubernetes workloads, TPU node pools, GKE cluster, and workload placement policy:

   ```bash
   ./cleanup.sh
   ```

## Additional resources

* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
* [TPUs in GKE documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/tpus)
* [LeaderWorkerSet (LWS) documentation](https://lws.sigs.k8s.io/)
