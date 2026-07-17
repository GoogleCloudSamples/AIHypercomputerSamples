# AI Hypercomputer samples
This repository contains code samples to help you run artificial intelligence and machine learning (AI/ML) workloads on Google Cloud. These samples demonstrate how to use AI Hypercomputer infrastructure, including Cloud TPUs and GPUs on Compute Engine and Google Kubernetes Engine (GKE). You will also find instructions for setting up large language model (LLM) libraries, such as MaxText.

This repository supports the following types of workloads:
* Pre-training
* Inference
* Post-training

## Intended audience

This content is for you if you are an AI developer, customer, or partner who needs to:
* Browse verified code snippets to deploy models directly on AI Hypercomputer infrastructure.
* Learn how to set up LLM libraries like MaxText and run AI/ML workloads on TPUs and GPUs using Compute Engine or GKE.

## Repository organization

The AI Hypercomputer samples repository is organized as follows:

```
.
├── gpu
│   ├── inference
│   ├── training
│   └── tuning
└── tpu
    ├── inference
    ├── training
    └── tuning
```

The`./gpu` and `./tpu` directories contain complete, end-to-end code samples with instructions for running AI/ML workloads on Google Cloud accelerators. The directories are organized into `inference`, `training`, and `tuning` subdirectories.
* `./inference`: This directory contains code samples and configurations that     demonstrate how to deploy models for serving predictions safely and             predictably on AI Hypercomputer infrastructure.
* `./training`: This directory contains code samples and tutorials to guide you through pre-training large language models from scratch using supported frameworks on Google Cloud accelerators.
* `./tuning`: This directory contains validated code samples and instructions for post-training and fine-tuning existing models to adapt them to your specific use cases.

## Sample structure

Each sample consists of the following files:
* `0_env.sh`: Contains all necessary starting environment variables.
* `cleanup.sh`: Contains instructions to terminate all created resources.
* `metadata.yaml`: Contains mandatory metadata for the sample testing, specifically the `expected_runtime` to prevent indefinite execution.
* `<N>_<step_name>.sh`: Contains the core execution scripts for the sample, broken down into sequential steps, for example, `1_download.sh` or `2_train.sh`.
* `*_validation.sh`: Contains instructions to export the necessary logs to debug and verify success. For example, using `grep` to check for specific output.

## Create a new sample

To create a new sample, follow these steps:
1. Prepare a step-by-step script that demonstrates your intended workflow.
2. Divide the script into logical steps and save them in separate shell scripts.
3. Add any necessary wait commands or wait loops so the scripts can be reliably executed without manual intervention.
4. Create a pull request, and include an example output log from your terminal that shows the scripts running successfully.

## Maintenance policy

This repository contains verified and validated code samples that are periodically tested to ensure they run reliably on AI Hypercomputer infrastructure. 

## Resources

For general guidance on using Google Cloud compute products, see the official documentation and tutorials:
* [Compute Engine overview](https://docs.cloud.google.com/compute/docs/overview)
* [Compute Engine samples](https://docs.cloud.google.com/compute/docs/samples)
* [Cloud TPU documentation](https://docs.cloud.google.com/tpu/docs)
* [AI Hypercomputer documentation](https://docs.cloud.google.com/ai-hypercomputer/docs)
* [Automated TPU environment deployment with Cluster Toolkit](https://cloud.google.com/cluster-toolkit/docs/deploy/gke/gke-tpu-overview)

## Report issues

If you have questions or encounter problems with this repository, report them through [GitHub Issues](https://github.com/GoogleCloudSamples/AIHypercomputerSamples/issues) or reach out to your Google Cloud account team for assistance.

## Contributor notes

**Note:** This is not an officially supported Google product. This project is not eligible for the [Google Open Source Software Vulnerability Rewards Program](https://bughunters.google.com/open-source-security).
