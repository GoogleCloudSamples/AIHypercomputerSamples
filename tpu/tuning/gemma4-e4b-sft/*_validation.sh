#!/bin/bash
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

set -euo pipefail

echo "== [Validation] Gemma 4 E4B SFT on ${TPU_NAME} =="

timeout 300 gcloud compute ssh "${TPU_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tunnel-through-iap \
    --quiet \
    --command="bash -s" <<'REMOTE'
set -euo pipefail

LOG_FILE="${HOME}/run_on_vm.log"
OUTPUTS_FILE="${HOME}/gemma4-e4b-sft-outputs.env"

echo "--- Debug: last 40 lines of ${LOG_FILE} ---"
tail -n 40 "${LOG_FILE}" 2>/dev/null || echo "No log file found."
echo "--- Debug: lines that mention the loss (last 10) ---"
grep -i 'loss' "${LOG_FILE}" 2>/dev/null | tail -n 10 || true
echo "--- Debug: /dev/shm usage ---"
df -h /dev/shm || true

if [ ! -f "${OUTPUTS_FILE}" ]; then
  echo "FAIL: ${OUTPUTS_FILE} not found. run_on_vm.sh did not finish successfully." >&2
  exit 1
fi
POST_TRAIN_PATH=$(grep '^POST_TRAIN_PATH=' "${OUTPUTS_FILE}" | cut -d= -f2-)
HF_EXPORT=$(grep '^HF_EXPORT=' "${OUTPUTS_FILE}" | cut -d= -f2-)

echo "--- Checking the final training checkpoint: ${POST_TRAIN_PATH} ---"
if [ -z "$(ls -A "${POST_TRAIN_PATH}" 2>/dev/null)" ]; then
  echo "FAIL: final training checkpoint ${POST_TRAIN_PATH} is missing or empty." >&2
  exit 1
fi
ls -l "${POST_TRAIN_PATH}"

echo "--- Checking the Hugging Face export: ${HF_EXPORT} ---"
ls -lh "${HF_EXPORT}" || true
python3 - "${HF_EXPORT}" <<'PY'
import glob
import json
import os
import re
import struct
import sys

export_dir = sys.argv[1]
errors = []

for name in ("config.json", "tokenizer.json"):
  if not os.path.isfile(os.path.join(export_dir, name)):
    errors.append(f"missing {name}")

shards = sorted(glob.glob(os.path.join(export_dir, "*.safetensors")))
if not shards:
  errors.append("no *.safetensors files")

tensors = {}
for shard in shards:
  with open(shard, "rb") as f:
    header_len = struct.unpack("<Q", f.read(8))[0]
    header = json.loads(f.read(header_len))
  header.pop("__metadata__", None)
  for key, info in header.items():
    tensors[key] = (shard, 8 + header_len, info)

expected_layers = None
if os.path.isfile(os.path.join(export_dir, "config.json")):
  with open(os.path.join(export_dir, "config.json")) as f:
    config = json.load(f)
  expected_layers = config.get("text_config", config).get("num_hidden_layers")

layers = {int(m.group(1)) for k in tensors for m in [re.search(r"\.layers\.(\d+)\.", k)] if m}
if expected_layers is None:
  errors.append("num_hidden_layers not found in config.json")
elif layers != set(range(expected_layers)):
  errors.append(f"decoder layers in export: {len(layers)}, expected {expected_layers}")

def check_finite(pattern):
  matches = sorted(k for k in tensors if re.search(pattern, k) and ".layers." not in k)
  if not matches:
    errors.append(f"no tensor matching {pattern}")
    return
  shard, data_start, info = tensors[matches[0]]
  if info["dtype"] != "BF16":
    errors.append(f"{matches[0]} has dtype {info['dtype']}, expected BF16")
    return
  begin, end = info["data_offsets"]
  end = min(end, begin + 2 * 65536)
  with open(shard, "rb") as f:
    f.seek(data_start + begin)
    raw = f.read(end - begin)
  values = struct.unpack(f"<{len(raw) // 2}H", raw)
  if any((v & 0x7F80) == 0x7F80 for v in values):
    errors.append(f"{matches[0]} contains NaN or Inf values")

check_finite(r"(^|\.)norm\.weight$")
check_finite(r"(^|\.)embed_tokens\.weight$")

print(f"Tensors: {len(tensors)}, decoder layers: {len(layers)}, shards: {len(shards)}")
if errors:
  for e in errors:
    print(f"FAIL: {e}", file=sys.stderr)
  sys.exit(1)
PY

echo "== [Validation] SUCCESS: SFT finished and the Hugging Face export is complete. =="
REMOTE
