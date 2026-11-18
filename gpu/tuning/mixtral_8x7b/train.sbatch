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

# Slurm batch wrapper for train-mixtral.sh, submitted by 2_run_job.sh.
# Unpacks the archived venv onto node-local NVMe on each node and runs
# train-mixtral.sh with HOME pointed at local NVMe, symlinking the shared
# model and outputs directories.

#SBATCH --job-name=mixtral-fsdp
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --partition=a4high
#SBATCH --output=mixtral-%j.out
#SBATCH --error=mixtral-%j.err
set -eo pipefail

REAL_HOME="${HOME}"
STAGE_HOME="/mnt/localssd/mixtral_stage_home"
WORK_TMP="/mnt/localssd/train_tmp_${SLURM_JOB_ID:-$$}"
VENV_ARCHIVE="${REAL_HOME}/.venv/venv-fsdp.tar"

cleanup() {
  HOME="${REAL_HOME}" srun --ntasks="${SLURM_NNODES}" --ntasks-per-node=1 bash -c "
    rm -f '${STAGE_HOME}/Mixtral-8x7B-v0.1' '${STAGE_HOME}/outputs'
    rm -rf '${STAGE_HOME}' '${WORK_TMP}'
  " || true
}
trap cleanup EXIT

mkdir -p "${REAL_HOME}/outputs"

# Unpack venv to local NVMe on each node and symlink shared model/outputs for train-mixtral.sh
srun --ntasks="${SLURM_NNODES}" --ntasks-per-node=1 bash -c "
  set -e
  rm -f '${STAGE_HOME}/Mixtral-8x7B-v0.1' '${STAGE_HOME}/outputs'
  rm -rf '${STAGE_HOME}' '${WORK_TMP}'
  mkdir -p '${STAGE_HOME}' '${WORK_TMP}/triton_cache' '${WORK_TMP}/tmp'
  tar -xf '${VENV_ARCHIVE}' -C '${STAGE_HOME}'
  ln -sfn '${REAL_HOME}/Mixtral-8x7B-v0.1' '${STAGE_HOME}/Mixtral-8x7B-v0.1'
  ln -sfn '${REAL_HOME}/outputs' '${STAGE_HOME}/outputs'
"

export HOME="${STAGE_HOME}"
export TRITON_CACHE_DIR="${WORK_TMP}/triton_cache"
export TMPDIR="${WORK_TMP}/tmp"

cd "${SLURM_SUBMIT_DIR}"
bash "${SLURM_SUBMIT_DIR}/train-mixtral.sh"
