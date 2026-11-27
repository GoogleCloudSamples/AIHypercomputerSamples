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

# Slurm batch wrapper for install_environment.sh, submitted by 2_run_job.sh.
# Builds the environment on node-local NVMe (/mnt/localssd) to avoid
# cross-region Managed Lustre small-file metadata latency, then stores the
# venv as a single tarball and the model weights on shared storage.

#SBATCH --job-name=env-setup
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --exclusive
#SBATCH --partition=a4high
#SBATCH --output=env-setup-%j.out
#SBATCH --error=env-setup-%j.err
set -eo pipefail

REAL_HOME="${HOME}"
STAGE_HOME="/mnt/localssd/mixtral_stage_home"
WORK_TMP="/mnt/localssd/env_setup_${SLURM_JOB_ID:-$$}"
VENV_ARCHIVE="${REAL_HOME}/.venv/venv-fsdp.tar"

if [ ! -d /mnt/localssd ] || [ ! -w /mnt/localssd ]; then
  echo "ERROR: Local SSD directory /mnt/localssd is not available or writable." >&2
  exit 1
fi

cleanup() {
  rm -rf "${STAGE_HOME}" "${WORK_TMP}" "${VENV_ARCHIVE}.tmp"
}
trap cleanup EXIT

rm -rf "${STAGE_HOME}" "${WORK_TMP}"
mkdir -p "${STAGE_HOME}" \
  "${WORK_TMP}/pip_cache" \
  "${WORK_TMP}/hf_cache" \
  "${WORK_TMP}/tmp" \
  "${WORK_TMP}/torch_extensions"

export PIP_NO_CACHE_DIR=1
export PIP_CACHE_DIR="${WORK_TMP}/pip_cache"
export HF_HOME="${WORK_TMP}/hf_cache"
export TMPDIR="${WORK_TMP}/tmp"
export TORCH_EXTENSIONS_DIR="${WORK_TMP}/torch_extensions"

cd "${SLURM_SUBMIT_DIR}"
HOME="${STAGE_HOME}" bash ./install_environment.sh

# Store the virtual environment as a single streaming tarball on shared storage.
mkdir -p "${REAL_HOME}/.venv"
tar -cf "${VENV_ARCHIVE}.tmp" -C "${STAGE_HOME}" .venv
mv -f "${VENV_ARCHIVE}.tmp" "${VENV_ARCHIVE}"

# Copy model weights to shared storage, excluding the HF download cache/locks.
mkdir -p "${REAL_HOME}/Mixtral-8x7B-v0.1"
rsync -a --exclude='.cache' "${STAGE_HOME}/Mixtral-8x7B-v0.1/" "${REAL_HOME}/Mixtral-8x7B-v0.1/"
