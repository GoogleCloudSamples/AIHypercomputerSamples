---
name: generate-sample-readme
description: >-
  Use this skill when the user asks to generate, create, or update a README.md file for a code sample in the AIHypercomputerSamples repository.
---

# AI Hypercomputer Sample README Generator

When you are asked to generate or update a `README.md` for a code sample directory in this repository, follow these precise instructions to ensure consistency.

## Step 1: Read the Template
Use your file tools to locate and read the contents of `sample_template/README.md` located in the root of the repository. This is the single source of truth for how the README must be formatted. Do NOT rely on hardcoded markdown structures in your memory.

## Step 2: Analyze the Sample Directory
- Read the `.sh` files in the directory (especially `0_env.sh`, setup/execution scripts, `*_validation.sh`, and `docs_snippets.sh`).
- **Determine Infrastructure**: Identify if the sample uses "GKE Autopilot", "GKE cluster with TPUs", or a cluster provisioned using "Google Cloud Cluster Toolkit" (e.g., uses the `gcluster` command).
- **Identify the Model**: Find the model name being used.
- **Determine Billable Resources**: Resources usually include Google Kubernetes Engine (GKE), Compute Engine (GPUs/TPUs), and Cloud Storage.
- **List the Steps**: Create a sequential list of all relevant `.sh` and `.yaml` scripts (using their exact filenames in the directory) and a short description of what they do.
- **Determine Verification Steps**: Identify the exact verification script (`./*_validation.sh`) or commands from `docs_snippets.sh` (such as `gcluster job logs`, `kubectl logs`, or `gcloud storage ls`) and expected log outputs.

## Step 3: Ask the User for the Tutorial Link
- Pause and ask the user to provide the official tutorial link for this specific sample.
- Wait for the user to reply with the link before proceeding.

## Step 4: Extract the Tutorial Title
- Once the user provides the link, use the `read_url_content` tool (or similar web tools) to fetch the web page.
- Extract the title of the tutorial from the page content.

## Step 5: Generate and Write the README
- Generate the README content by mapping the extracted sample details, the tutorial URL, and the tutorial title into the exact structure you read from the template in Step 1.
- Do NOT add extra sections or headings that are not in `sample_template/README.md` (such as `## Tutorial`, `## Architecture and Workload`, `## Architecture`, or `## Overview`). Keep all architecture details, the file list, and the tutorial link in the introduction section directly under the main `#` title.
- Under `## Verify the results`, always provide concrete verification commands and expected outputs rather than generic instructions like "Check the logs of the training job."
- Replace the `*TUTORIAL_TITLE*` and `*[Link to official AI Hypercomputer tutorial on Google Cloud]*` placeholders with the actual title and link. Remove any other unneeded generic placeholders from the "Additional resources" section.
- Use the `write_to_file` tool to save the generated content to `README.md` inside the target sample's directory.
