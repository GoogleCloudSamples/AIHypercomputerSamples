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
#
# This script should be run ONCE on the login node to set up the
# shared Python virtual environment.
# [START hypercomputer_gpu_train_qwen2_slurm_install_environment]
set -e
echo "--- Creating Python virtual environment in /home ---"
python3 -m venv ~/.venv
echo "--- Activating virtual environment ---"
source ~/.venv/bin/activate

echo "--- Installing build dependencies ---"
pip install --upgrade pip wheel packaging

echo "--- Installing PyTorch for CUDA 12.8 ---"
pip install torch --index-url https://download.pytorch.org/whl/cu128

echo "--- Installing application requirements ---"
pip install -r requirements.txt

echo "--- Environment setup complete. You can now submit jobs with sbatch. ---"
# [START hypercomputer_gpu_train_qwen2_slurm_install_environment]
