# Preparing new code sample

## Required files
A proper code sample is build out of following files:

* `0_env.sh`: Containing all necessary starting environment variables.
* `cleanup.sh`: Containing instructions to terminate all created resources.
* `metadata.yaml`: Mandatory metadata for the sample testing, specifically the `expected_runtime` to prevent indefinite execution.
* `<N>_<step_name>.sh`: Code sample proper body divided into separate files.
* `*_validation.sh`: Includes instructions to dump necessary logs for debugging and verify success (e.g., using grep to check for specific output).

Prepare your code in a way that can be executed by simply executing the shell scripts in correct order, without any 
additional actions from the user.

### Best practice for writing samples

* Remember to set `set -euo pipefail` at the beginning of your files, so that any failure during sample run is noticed.
* Use wait loops to let resources get properly created in cases where the creation command can return before resource is
  ready to be used. For example, after creating a new TPU VM, you can wait for it to be ready with:

```bash
LIMIT=60
count=0
while ! gcloud compute tpus tpu-vm describe $TPU_NAME --project $PROJECT_ID --zone $ZONE | grep -q 'state: READY'; do
  if [ $count -ge $LIMIT ]; then
    echo "Timeout waiting for TPU to become READY." >&2
    exit 1
  fi
  sleep 10
  count=$((count+1))
done 
```

* Allow for easy reusability of your code by making use of environmental variables. For example, don't hardcode model
  names, regions, zones or machine types.
* Use `--project $PROJECT_ID` flag for your `gcloud` commands, to be explicit about which project is used.

## Region tags

To allow importing of code snippets into Google Cloud documentation, you need to mark the code with proper region tags.

Typically, region tags for Python and shell scripts look the same - they are a comment in the following format:

```bash
# [START hypercomputer_<region_tag_name>]
...
# [END hypercomputer_<region_tag_name>]
```

To read more about region tags in [Sample Style Guide](https://googlecloudplatform.github.io/samples-style-guide/).

## Prepare README file

Remember to write at least a basic `README.md` file pointing at the official documentation page that uses your code sample (when it's ready).
