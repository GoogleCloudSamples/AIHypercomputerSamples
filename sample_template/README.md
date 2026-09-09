# _[Sample title]_
# Example: Fine-tune Gemma 3 on an A4 Slurm cluster

_[Provide 1-2 sentences stating the purpose of the sample and the intended audience. If applicable, explicitly state what is not covered by this sample (for example, dataset preparation, serving the model in a production environment, or configuring VPC networks from scratch) to help users quickly determine if it meets their needs. The next sentence is an example of an introductory sentence. Delete the instructions provided in brackets and the examples after you add your own content.]_

Example: This code sample is intended for AI/ML engineers and demonstrates how to fine-tune the Gemma 3 model by using a Slurm cluster that’s deployed on A4 VMs on Google Cloud. 

Note: This sample doesn’t demonstrate how to prepare a dataset or serve the model in production.

_[Provide a high-level description of the architecture, workload, and how the scripts interact. Follow this description with a bulleted list of the scripts in the directory.]_

Example: The scripts in this directory deploy the infrastructure and run the AI/ML workload on AI Hypercomputer. The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables, such as the project ID, zone, and Hugging Face token.
* `1_deploy_cluster.sh`: Uses the Google Cloud Cluster Toolkit to provision the Slurm cluster infrastructure.
* `2_run_job.sh`: Submits the sbatch job that uses Accelerate to distribute the fine-tuning workload across the GPUs.
* `3_validation.sh`: Checks the output logs for the final training loss to verify success.
* `cleanup.sh`: Terminates all created resources.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - _[Provide a list of billable resources such as VMs and storage]_.
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* _[Provide the necessary quota for the required hardware.]_
  
  Example: Quota for A4 VMs (for example, a3-highgpu-8g) in your chosen region.
  
* _[Specify any specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools.]_
  
  Example: A valid Hugging Face token (HF_TOKEN) with access to the Gemma 3 model or the cluster-toolkit CLI installed on your local machine.

## Run the sample

_[Provide the step-by-step instructions to execute the sample, including setting environment variables, deploying infrastructure, and running the job.]_

To execute this sample, follow these steps:

1. _[Add the first step, for example, setting up environment variables by editing and sourcing the environment script.]_
   
   Example: Open `0_env.sh` and update the `PROJECT_ID`, `ZONE`, and `HF_TOKEN` variables.
   
   ```bash
   source 0_env.sh
   ```

## Verify the results

_[Provide steps to verify that the workload ran successfully. Describe the expected output or success criteria the user should see in the logs.]_

To verify that the workload ran successfully:

1. _[Check the logs and validate the output.]_
   
   Example: Run the validation script to check the Slurm output logs for the final training loss:

   ```bash
   ./3_validation.sh
   ```

2. _[Describe the expected output or success criteria the user should see in the logs.]_

   Example: You should see an output indicating `Validation passed` and the training loss.

## Clean up

_[Provide instructions to terminate all created resources to avoid unnecessary charges.]_

To clean up the resources created by this sample:

1. _[Delete resources]_

   Example: Delete the Slurm cluster and clean up the workspace:

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
* _[Link to related concepts or tools used in the sample]_
