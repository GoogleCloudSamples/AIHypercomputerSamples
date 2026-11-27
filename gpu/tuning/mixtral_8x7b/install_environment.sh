#!/bin/bash
#
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

# [START hypercomputer_gpu_tune_mixtral_slurm_install_environment]
#!/bin/bash
# This script sets a reliable environment for FSDP training.
# It is meant to be run on a compute node.
set -e

# --- 1. Create the Python virtual environment ---
VENV_PATH="$HOME/.venv/venv-fsdp"
if [ ! -d "$VENV_PATH" ]; then
  echo "--- Creating Python virtual environment at $VENV_PATH ---"
  python3 -m venv $VENV_PATH
else
  echo "--- Virtual environment already exists at $VENV_PATH ---"
fi

source $VENV_PATH/bin/activate

# --- 2. Install Dependencies ---
echo "--- [STEP 2.1] Upgrading build toolchain ---"
pip install --upgrade pip wheel packaging ninja

echo "--- [STEP 2.2] Installing PyTorch ---"
TORCH_VERSION="2.10.0"
pip install --force-reinstall "torch==${TORCH_VERSION}" --index-url https://download.pytorch.org/whl/cu128

echo "--- [STEP 2.3] Installing application dependencies ---"
if [ -f "requirements-fsdp.txt" ]; then
    pip install -r requirements-fsdp.txt
else
    echo "ERROR: requirements-fsdp.txt not found!"
    exit 1
fi

# --- [STEP 2.4] Build Flash Attention from Source ---
echo "--- Building flash-attn from source... This will take a while. ---"
# Bypass PyTorch CUDA version mismatch check for extension builds
python3 -c "
import torch.utils.cpp_extension as ce
p = ce.__file__
content = open(p).read().replace('raise RuntimeError(CUDA_MISMATCH_MESSAGE', 'pass # raise RuntimeError')
open(p, 'w').write(content)
"

# Target B200 (sm_100) only and parallelize builds across all CPU cores
export FLASH_ATTN_CUDA_ARCHS="100"
export NVCC_THREADS="1"
MAX_JOBS=$(nproc) pip install flash-attn==2.8.3 --no-build-isolation

# --- 3. Download the Model ---
echo "--- [STEP 2.5] Downloading Mixtral model ---"
if [ -z "$HF_TOKEN" ]; then
  echo "ERROR: The HF_TOKEN environment variable is not set."; exit 1;
fi
pip install huggingface_hub[cli]

# Download only safetensors weights, configs, and tokenizer (skip unused .pt checkpoints)
# to reduce download and copy time.
$VENV_PATH/bin/hf download mistralai/Mixtral-8x7B-v0.1 \
  --include "*.safetensors" "*.json" "tokenizer.model" \
  --local-dir ~/Mixtral-8x7B-v0.1 --token $HF_TOKEN

echo "--- Environment setup complete. ---"
# [END hypercomputer_gpu_tune_mixtral_slurm_install_environment]