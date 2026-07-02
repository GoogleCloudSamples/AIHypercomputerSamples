# Automated Deployment of Llama 4 on GKE with vLLM

This directory contains a set of bash scripts to demonstrate the full end-to-end implementation process of deploying and serving the Llama 4 large language model (LLM) using vLLM on Google Kubernetes Engine (GKE) with GPUs. These scripts streamline the steps outlined in the Google Cloud tutorial: [Use vLLM on GKE to run inference with Llama 4](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials/gpu/vllm-gke-llama4).

## Overview

The scripts in this repository perform the following actions:

1.  **Environment Setup:** Configures necessary environment variables.
2.  **GKE & Secret Setup:** Creates a GKE Autopilot cluster and a Kubernetes Secret to securely store your Hugging Face token.
3.  **vLLM Deployment:** Deploys a vLLM server on GKE, configured to serve the Llama 4 Scout (17Bx16E) model using GPU resources.
4.  **Inference Test:** Provides a command to test the deployed model with a sample inference request.
5.  **Cleanup:** Removes all resources created by the scripts to avoid ongoing costs.
