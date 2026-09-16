# _[Sample title]_

_[Provide 1-2 sentences stating the purpose of the sample and the intended audience. If applicable, explicitly state what is not covered by this sample (for example, dataset preparation, serving the model in a production environment, or configuring VPC networks from scratch) to help users quickly determine if it meets their needs. The next sentence is an example of an introductory sentence. Delete the instructions provided in brackets and the examples after you add your own content.]_

_[Provide a high-level description of the architecture, workload, and how the scripts interact. Follow this description with a bulleted list of the scripts in the directory.]_

The sample includes the following files:

* `0_env.sh`: Contains the starting environment variables.
* `1_setup.sh`: Sets up the cluster and infrastructure.
* `2_deploy.sh`: Deploys the model.
* `*_validation.sh`: Validates the workload.
* `cleanup.sh`: Terminates all created resources.
* `docs_snippets.sh`: Documentation snippets.
* `gpu-recipes/`: Directory containing recipes.
* `metadata.yaml`: Metadata file.

For the complete step-by-step tutorial of how to use this sample, see the official Google Cloud documentation: _TUTORIAL_TITLE_.

## Before you begin

Before you run this sample, ensure you have the following:

* A Google Cloud project with billing enabled. Running this sample provisions billable Google Cloud resources including:
  - _[Provide a list of billable resources such as VMs and storage]_.
  
  You are billed for these resources for the time that they are running. To avoid incurring charges, delete the resources when you have finished running the sample.
* _[Provide the necessary quota for the required hardware.]_
  
* _[Specify any specific prerequisites, such as Hugging Face tokens, IAM permissions, or installed tools.]_

## Run the sample

_[Provide the step-by-step instructions to execute the sample, including setting environment variables, deploying infrastructure, and running the job.]_

To execute this sample, follow these steps:

1. Update and source the environment variables:
   
   ```bash
   source 0_env.sh
   ```

2. Run the setup script:

   ```bash
   ./1_setup.sh
   ```

3. Deploy the model:

   ```bash
   ./2_deploy.sh
   ```

## Verify the results

_[Provide steps to verify that the workload ran successfully. Describe the expected output or success criteria the user should see in the logs.]_

To verify that the workload ran successfully:

1. _[Check the logs and validate the output.]_

   ```bash
   ./*_validation.sh
   ```

2. _[Describe the expected output or success criteria the user should see in the logs.]_

## Clean up

_[Provide instructions to terminate all created resources to avoid unnecessary charges.]_

To clean up the resources created by this sample:

1. _[Delete resources]_

   ```bash
   ./cleanup.sh
   ```
  
## Additional resources
  
* _[Link to official AI Hypercomputer tutorial on Google Cloud]_
* _[Link to related concepts or tools used in the sample]_
