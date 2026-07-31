# Automated Deployment of Llama 4 on GKE G4 (NVIDIA RTX Pro 6000) with vLLM

This directory contains a set of bash scripts to demonstrate the full end-to-end implementation process of deploying and serving the Llama 4 large language model (LLM) using vLLM on Google Kubernetes Engine (GKE) with G4 accelerator nodes (8x NVIDIA RTX Pro 6000 GPUs).

## Overview

The scripts in this repository perform the following actions:

1. **Environment Setup:** Configures necessary environment variables.
2. **Infrastructure & Secret Setup:** Enables Google Cloud APIs, provisions storage components, configures Artifact Registry, and creates a Kubernetes Secret to securely store your Hugging Face token.
3. **Cluster & Image Build:** Creates a GKE cluster with G4 (8x RTX Pro 6000 GPUs) node pools and builds the custom vLLM container image using Cloud Build.
4. **vLLM Deployment:** Deploys a vLLM server on GKE using Helm and applies required G4 GPU toleration patches to serve the Llama 4 Scout (17Bx16E) model.
5. **Inference Test:** Provides a command to test the deployed model with a sample inference request.
6. **Cleanup:** Removes all resources created by the scripts to avoid ongoing costs.
