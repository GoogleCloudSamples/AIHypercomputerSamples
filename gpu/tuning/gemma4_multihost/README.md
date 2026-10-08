# Fine-tune Gemma 4 on a multi-host GKE cluster

This set of scripts demonstrates the end-to-end implementation featured in our
official Google Cloud documentation:

* [Fine-tune Gemma 4 on a multi-host A4 GKE cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma4-finetune-a4-gke-multi-host-cluster)

This sample demonstrates how to fine-tune a Gemma 4 31B model
(`google/gemma-4-31b-it`) on a multi-host Google Kubernetes Engine (GKE)
Autopilot cluster orchestrated with Kubernetes `JobSet` and Hugging Face
Accelerate Fully Sharded Data Parallel (FSDP v2) across 16 NVIDIA B200 GPUs
(2x `a4-highgpu-8g` VM instances).
