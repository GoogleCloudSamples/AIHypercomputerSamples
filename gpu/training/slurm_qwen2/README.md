#  Qwen2 on an A4 Slurm cluster

This repository contains code samples and scripts from the AI Hypercomputer documentation.

## Tutorial

For a step-by-step guide on how to use these files, please refer to the official tutorial:
*   **[Train Qwen2 on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/train-qwen2-a4-slurm-cluster)**

## Overview

This sample demonstrates how to pre-train a Qwen2 1.5B large language model (LLM) on a multi-node Slurm cluster that uses two A4 virtual machine (VM) instances equipped with NVIDIA B200 GPUs. For efficient multi-node training, it uses the Hugging Face Accelerate library with Fully Sharded Data Parallel (FSDP).
