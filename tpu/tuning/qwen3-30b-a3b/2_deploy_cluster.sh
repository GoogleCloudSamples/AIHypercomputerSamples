#  Copyright 2026 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

#!/bin/bash

set -euo pipefail

echo "[$(date)] ==================== Starting GKE Cluster Deployment & Training and Setup ===================="

# 1. Set up Python virtual environment and install XPK
echo "Setting up Python virtual environment for XPK..."
VENV_DIR="xpk_venv"

if [ -d "$VENV_DIR" ] && [ ! -f "$VENV_DIR/bin/activate" ]; then
    rm -rf "$VENV_DIR"
fi

if [ ! -d "$VENV_DIR" ]; then
    if ! python3 -c "import venv, ensurepip" &>/dev/null; then
        PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        echo "Required Python venv modules are missing. Installing python${PY_VERSION}-venv..."
        sudo apt update && sudo apt install -y "python${PY_VERSION}-venv" || {
            echo "Error: Package installation failed. Run manually: sudo apt update && sudo apt install -y python${PY_VERSION}-venv" >&2
            exit 1
        }
    fi
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

echo "Installing xpk version 1.13.1..."
pip install --upgrade pip
pip install xpk==1.13.1

# 2. Create GKE Pathways Cluster (if it doesn't exist)
echo "Checking if GKE cluster ${CLUSTER_NAME} already exists..."
if gcloud container clusters describe "${CLUSTER_NAME}" --location="${REGION}" --project="${PROJECT}" &>/dev/null; then
    echo "GKE cluster ${CLUSTER_NAME} already exists. Skipping creation."
else
    echo "Creating GKE cluster with Pathways support (this may take several minutes)..."
    xpk cluster create-pathways \
        --num-slices="${CLUSTER_NODEPOOL_COUNT}" \
        --tpu-type="${TPU_TYPE}" \
        --pathways-gce-machine-type="${PW_CPU_MACHINE_TYPE}" \
        --project="${PROJECT}" \
        --zone="${ZONE}" \
        --cluster="${CLUSTER_NAME}" \
        --custom-cluster-arguments="--enable-ip-alias" \
        --custom-nodepool-arguments="--disk-size=500"
fi

# 3. Configure kubectl credentials context
echo "Fetching cluster credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --location="${REGION}" --project "${PROJECT}"

# 4. Initialize XPK metadata (ConfigMaps) and install required controllers
echo "Synchronizing GKE cluster metadata and resources ConfigMaps..."
export RESERVATION=""

xpk cluster create \
    --cluster="${CLUSTER_NAME}" \
    --project="${PROJECT}" \
    --zone="${ZONE}" \
    --tpu-type="${TPU_TYPE}" \
    --num-slices="${CLUSTER_NODEPOOL_COUNT}" \
    --on-demand

echo "Installing/updating Kueue controller (v0.6.2)..."
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.6.2/manifests.yaml

echo "Installing/updating JobSet controller (v0.5.2)..."
kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/v0.5.2/manifests.yaml

# 5. Start Model Conversion Workload (Hugging Face to MaxText)
echo "Submitting model checkpoint conversion workload..."
xpk workload create \
  --workload "qwen-hf-to-mt" \
  --docker-image "${CLOUD_IMAGE_NAME}" \
  --cluster "${CLUSTER_NAME}" \
  --tpu-type="${TPU_TYPE}" \
  --num-slices=1 \
  --project="${PROJECT}" \
  --zone="${ZONE}" \
  --injection-failure-policy=false \
  --command "[ \"\$JOB_COMPLETION_INDEX\" != \"0\" ] || \
        python3 -m maxtext.checkpoint_conversion.to_maxtext \
          model_name=${MODEL_NAME} \
          hf_access_token=${HF_TOKEN} \
          --hf_model_path='Qwen/Qwen3-30B-A3B-Instruct-2507' \
          base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/ \
          scan_layers=True \
          use_multimodal=False \
          skip_jax_distributed_system=true \
          checkpoint_storage_use_zarr3=0 \
          checkpoint_storage_use_ocdbt=0 \
          hardware=cpu \
          --lazy_load_tensors=True"

echo "Model conversion job submitted."

# 6. Wait for model conversion to complete before starting RL training
echo "Waiting for the checkpoint conversion job to complete successfully..."
kubectl wait --for=condition=complete --timeout=1800s job/qwen-hf-to-mt-slice-job-0 || {
    echo "Error: Checkpoint conversion job failed or timed out." >&2
    exit 1
}
echo "Model conversion completed successfully."

# 7. Start the RL Training Workload
echo "Submitting RL Training workload via XPK..."
xpk workload create-pathways \
  --cluster="${CLUSTER_NAME}" \
  --project="${PROJECT}" \
  --zone="${ZONE}" \
  --docker-image="${CLOUD_IMAGE_NAME}" \
  --workload="qwen-training" \
  --tpu-type="${TPU_TYPE}" \
  --num-slices=1 \
  --injection-failure-policy=false \
  --command="JAX_PLATFORMS=proxy,cpu JAX_BACKEND_TARGET=grpc://127.0.0.1:29000 ENABLE_PATHWAYS_PERSISTENCE=1 \
      python3 -m maxtext.trainers.post_train.rl.train_rl \
      run_name=rl \
      base_output_directory=gs://${GCS_BUCKET}/${MODEL_NAME}/trained/ \
      model_name=${MODEL_NAME} \
      load_parameters_path=gs://${GCS_BUCKET}/${MODEL_NAME}/max-text-format/0/items/ \
      hf_access_token=${HF_TOKEN} \
      num_batches=50 \
      per_device_batch_size=1 \
      batch_size=4 \
      rollout_tensor_parallelism=4 \
      rollout_expert_parallelism=4 \
      trainer_devices_fraction=0.5 \
      sampler_devices_fraction=0.5 \
      tokenizer_path='Qwen/Qwen3-30B-A3B-Instruct-2507' \\
      ici_tensor_parallelism=4 \
      ici_expert_parallelism=4 \
      hbm_utilization_vllm=0.2 \
      async_scheduling=False \
      allow_split_physical_axes=true \
      debug.rl=True \
      vllm_hf_overrides='{architectures: [\"MaxTextForCausalLM\"]}' \
      vllm_additional_config=\"{'maxtext_config': {'model_name': '${MODEL_NAME}', 'allow_split_physical_axes': 'true', weight_dtype: bfloat16}}\""

echo "RL Training workload successfully orchestrated."
echo "Monitor workload status: xpk workload list --cluster ${CLUSTER_NAME} --project ${PROJECT} --zone ${ZONE}"
