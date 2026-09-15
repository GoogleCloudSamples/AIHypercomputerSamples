# Fine-tune Gemma 4 on GKE

This set of scripts demonstrates the full end-to-end implementation of a model use case
featured in our official Google Cloud documentation:

* [Fine-tune Gemma 4 on an A4 GKE cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma4-finetune-a4-gke-cluster)

This sample demonstrates how to fine-tune a Gemma 4 31B model (`google/gemma-4-31B-it`) on a Google Kubernetes Engine (GKE) Autopilot cluster using Hugging Face Accelerate with Fully Sharded Data Parallel (FSDP). It uses 8 NVIDIA B200 GPUs (A4 VM instance).
