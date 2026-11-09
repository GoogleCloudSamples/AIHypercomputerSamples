# Fine-tune Gemma 3 on an A4 Slurm cluster

This repository contains code samples and scripts from the AI Hypercomputer documentation.

## Tutorial

For a step-by-step guide on how to use these files, please refer to the official tutorial:
*   **[Fine-tune Gemma 3 on an A4 Slurm cluster](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/gemma-3-slurm-cluster)**

## Overview

This sample demonstrates how to fine-tune a Gemma 3 12B large language model (LLM) on a multi-node Slurm cluster that uses two A4 virtual machine (VM) instances. For efficient multi-node training, it uses the Hugging Face Accelerate library with Fully Sharded Data Parallel (FSDP).
