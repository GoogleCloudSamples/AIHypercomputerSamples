# Fine-tune Gemma 4 Vision using Ray on GKE

This set of scripts demonstrates the full end-to-end implementation of a model use case featured in our official Google Cloud documentation:

* [Use Ray to fine-tune Gemma 4 on a vision task in GKE](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/use-ray-fine-tune-gemma-vision-task-gke)

This sample demonstrates how to fine-tune a Gemma 4 Vision model (`google/gemma-4-E4B-it`) on a Google Kubernetes Engine (GKE) Autopilot cluster using Ray Train with the TRL (Transformer Reinforcement Learning) SFTTrainer. It uses 16 NVIDIA B200 GPUs.