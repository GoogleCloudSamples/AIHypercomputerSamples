# Generate Sample README Skill

This directory contains the `generate-sample-readme` skill, which automates the creation and formatting of `README.md` files for AI Hypercomputer code samples. The skill ensures that all sample documentation strictly adheres to the official repository template (`sample_template/README.md`).

## What it does

When invoked, the skill:
1. Locates and reads the central `sample_template/README.md`.
2. Analyzes the target sample's `.sh` and `.yaml` scripts to dynamically determine the infrastructure, billable resources, steps, and target model.
3. Rewrites the sample's `README.md` to perfectly match the template, filling in the custom descriptive text.
4. Seamlessly injects the official tutorial documentation link (and extracts the web page's title) if you provide the tutorial URL.

## How to use it

If you are using Gemini (or the Jetski agent system), you can instruct the agent to use this skill when creating a new sample or updating an old one. 

**Example Prompts:**
* *"I just created a new sample in `gpu/inference/new-model`. Please use the `generate-sample-readme` skill to generate its README."*
* *"Please run the `generate-sample-readme` skill for `tpu/tuning/my-sample`. The tutorial URL is `https://docs.cloud.google.com/ai-hypercomputer/docs/...`"*

If you do not provide the tutorial URL in your initial prompt, the skill will pause its execution and ask you to provide it before finishing the document.
