# AI Hypercomputer Samples
This repo contains samples to help you run AI/ML workloads with AI Hypercomputer infrastructure, namely, TPUs and GPUs that run on Compute Engine and GKE and include instructions about how to set up LLM libraries like MaxText.

This repo supports the following types of workloads:
* Pre-training
* Inference
* Post-training

## Repository structure
The repository is organized as follows:

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

In those directories you can find full end-to-end code samples that are periodically
validated.

### Sample structure

Each sample consists of following files:

* `0_env.sh`: Containing all necessary starting environment variables.
* `cleanup.sh`: Containing instructions to terminate all created resources.
* `metadata.yaml`: Mandatory metadata for the sample testing, specifically the `expected_runtime` to prevent indefinite execution.
* `<N>_<step_name>.sh`: Code sample proper body divided into separate files.
* `*_validation.sh`: Includes instructions to dump necessary logs for debugging and verify success (e.g., using `grep` to check for specific output).

## Creating new sample

To create a new sample follow these steps:
1. Prepare a step by step script that demonstrates what you want to do.
2. Break it up into logical steps and save it in separate shell scripts.
3. Add necessary wait commands or wait loops, so the scripts can be reliably executed without human in the loop.
4. Prepare a new Pull Request, where you provide an example output log from your terminal of you running the scripts.

## Official docs
[AI Hypercomputer official documentation](https://docs.cloud.google.com/ai-hypercomputer/docs/overview)

This repo contains the sample code that is used in the official [AI Hypercomputer tutorials](https://docs.cloud.google.com/ai-hypercomputer/docs/tutorials). For the best experience running workloads, we recommend that you refer to the official docs in addition to the samples contained within this repo.

## How to contribute
This project isn't currently accepting contributions.
