---
name: generate-sample-readme
description: >-
  Use this skill when the user asks to generate, create, or update a README.md file for a code sample in the AIHypercomputerSamples repository.
---

# AI Hypercomputer sample README generator

When you are asked to generate or update a `README.md` for a code sample directory in this repository, follow these precise instructions to ensure consistency.

## Step 1: Read the template
Use your file tools to locate and read the contents of `sample_template/README.md` located in the root of the repository. This is the single source of truth for how the README must be formatted. Do NOT rely on hardcoded markdown structures in your memory.

## Step 2: Analyze the sample directory
- Read the `.sh` files in the directory (especially `0_env.sh`, setup/execution scripts, `*_validation.sh`, and `docs_snippets.sh`).
- **Determine Infrastructure**: Identify if the sample uses "GKE Autopilot", "GKE cluster with TPUs", or a cluster provisioned using "Cluster Toolkit" (for example, uses the `gcluster` command).
- **Identify the Model**: Find the official model name being used (such as `DeepSeek-V3.1-Base`, `DeepSeek-V3.2-Speciale`, `Llama 4 Scout`, or `Gemma 4 31B`) so it matches the linked tutorial, and keep hardware/VM series names (such as `A4` or `G4`) separate from the model name.
- **Determine Billable Resources**: Resources usually include Google Kubernetes Engine (GKE), Compute Engine (GPU and CPU VMs), Cloud TPU (always list Cloud TPU as its own bullet point separate from Compute Engine), and Cloud Storage (always use the official name "Cloud Storage" or "Cloud Storage FUSE", not "Google Cloud Storage" or "GCS").
- **List the Steps**: Create a sequential list of all relevant `.sh` and `.yaml` scripts (using their exact filenames in the directory) and a short description of what they do. Start each file description with a present-tense verb (for example, "Configures the job.", "Contains documentation snippets.", "Configures the model.").
- **Determine Verification Steps**: Identify the exact verification script (`./*_validation.sh`) or commands from `docs_snippets.sh` (such as `gcluster job logs`, `kubectl logs`, or `gcloud storage ls`) and expected log outputs.

## Step 3: Ask the user for the tutorial link
- Pause and ask the user to provide the official tutorial link for this specific sample.
- Wait for the user to reply with the link before proceeding.

## Step 4: Extract the tutorial title
- Once the user provides the link, use the `read_url_content` tool (or similar web tools) to fetch the web page.
- Extract the title of the tutorial from the page content.

## Step 5: Generate and write the README
- Generate the README content by mapping the extracted sample details, the tutorial URL, and the tutorial title into the exact structure you read from the template in Step 1.
- Format the main `#` title using an imperative verb, the official model name, and the target hardware/cluster following the template pattern `# [Verb] [Model] on a [Hardware/Cluster]` (for example, `# Serve DeepSeek-V3.1-Base on a GKE cluster`, `# Serve Llama 4 Scout on an A4 GKE cluster`, or `# Fine-tune Gemma 4 31B on a TPU GKE cluster`).
- Do NOT add extra sections or headings that are not in `sample_template/README.md` (such as `## Tutorial`, `## Architecture and Workload`, `## Architecture`, or `## Overview`). Keep all architecture details, the file list, and the tutorial link in the introduction section directly under the main `#` title.
- Under `## Before you begin`, never generalize any bullet point (avoid phrases like "(if used for model storage)", "(if the model requires authentication)", "with access to the model", or "Appropriate IAM permissions for..."). Inspect the sample's scripts and manifests to list only the exact billable resources provisioned, the exact hardware quota and reservation variable (for example, `a4-highgpu-8g` with 8 NVIDIA B200 GPUs per node, or Cloud TPU `v6e-8` with 8 TPU v6e chips), the exact Hugging Face model ID and token variable (`HF_TOKEN` or `HUGGING_FACE_TOKEN`), the exact CLI tools invoked by the scripts (`gcloud`, `kubectl`, `envsubst`, `helm`, `git`, `docker`, `python3`), and the specific Identity and Access Management (IAM) actions and roles required by the sample, each as a separate bullet point.
- Under `## Verify the results`, always provide concrete verification commands and expected outputs rather than generic instructions like "Check the logs of the training job."
- Under `## Clean up`, if there is only a single cleanup step (`./cleanup.sh`), format it as a single unnumbered step (`To clean up the resources created by this sample, run the cleanup script:` followed by the code block) rather than a `1.` numbered list item, since numbered lists must have at least 2 items.
- Follow the [Google Developer Documentation Style Guide](https://developers.google.com/style/word-list):
  - Use sentence case for all headings (`#` and `##`), capitalizing only the first word and proper nouns or official abbreviations (for example, `# Fine-tune Gemma 4 26B on a TPU GKE cluster` and `# Fine-tune Gemma 4 31B on a TPU GKE cluster`), and do not define or wrap abbreviations in parentheses in headings.
  - Start every file description in the bulleted file list with a present-tense verb (for example, "Configures the job." instead of "Job configuration.").
  - Expand abbreviations on their first use in the document body—such as "Google Kubernetes Engine (GKE)", "Virtual Private Cloud (VPC)", "Identity and Access Management (IAM)", "virtual machine (VM)", "Fully Sharded Data Parallel (FSDP)", "supervised fine-tuning (SFT)", "reinforcement learning (RL)", and "Dynamic Resource Allocation for Networking (DRANET)" (do not capitalize common nouns such as "virtual machines", "reinforcement learning", "supervised fine-tuning", or "persistent volumes" in prose)—and use the abbreviation on subsequent mentions.
  - Use "for example" or "such as" instead of "e.g.", and avoid "etc." and "i.e.".
  - Use "using" instead of "via", and use "use" / "using" instead of "utilize" / "utilizing".
  - Always use the official product and framework names "Cloud TPU" (not "Google Cloud TPUs"), "Cloud Storage" (or "Cloud Storage FUSE", not "Google Cloud Storage" or "GCS"), "Cluster Toolkit" (not "Google Cloud Cluster Toolkit"), "Dynamic Resource Allocation for Networking (DRANET)" on first mention followed by "DRANET" on subsequent mentions (not "DraNet" or "Dynamic Resource Allocation (DRANET)"), "verl" (not "veRL" or "vERL"), and "Google Cloud Managed Lustre" on first mention followed by "Managed Lustre" on subsequent mentions (not "Lustre").
  - Wrap all CLI tools, commands, machine/TPU types, and environment variable names (such as `gcloud`, `kubectl`, `gcluster`, `cluster-toolkit`, `a4-highgpu-8g`, `v6e-8`, and `HF_TOKEN`) in backticks.
- Replace the `*TUTORIAL_TITLE*` and `*[Link to official AI Hypercomputer tutorial on Google Cloud]*` placeholders with the actual title and link. Remove any other unneeded generic placeholders from the "Additional resources" section.
- Use the `write_to_file` tool to save the generated content to `README.md` inside the target sample's directory.
