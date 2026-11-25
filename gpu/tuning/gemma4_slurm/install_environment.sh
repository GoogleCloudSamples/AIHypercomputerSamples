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

# [START hypercomputer_gpu_tune_gemma4_slurm_install_environment]
#!/bin/bash
set -euo pipefail

# Run this script once on the login node to create the shared Python virtual
# environment.
TORCH_VERSION="2.11.0"

echo "--- Creating Python virtual environment in /home ---"
python3 -m venv ~/.venv

echo "--- Installing build dependencies ---"
~/.venv/bin/pip install --upgrade pip wheel packaging

echo "--- Installing PyTorch ${TORCH_VERSION} for CUDA 12.8 ---"
~/.venv/bin/pip install "torch==${TORCH_VERSION}" --index-url https://download.pytorch.org/whl/cu128

echo "--- Installing application requirements ---"
~/.venv/bin/pip install -r requirements.txt "torch==${TORCH_VERSION}"

echo "--- Environment setup complete. You can now submit jobs with sbatch. ---"
# [END hypercomputer_gpu_tune_gemma4_slurm_install_environment]
