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

set -euo pipefail

echo "Waiting for the Mixtral 8x7B JobSet to complete and summarizing throughput..."
# [START hypercomputer_gpu_train_mixtral_8x7b_benchmark_summary]
kubectl wait --for=condition=Completed jobset/mixtral-8x7b --timeout=1800s

kubectl logs \
  -l jobset.sigs.k8s.io/jobset-name=mixtral-8x7b,batch.kubernetes.io/job-completion-index=1 \
  -c megatron-lm \
  --tail=-1 > /tmp/megatron_train.log

python3 - /tmp/megatron_train.log << 'EOF'
import pathlib
import re
import statistics
import sys

logs = pathlib.Path(sys.argv[1]).read_text()

step_pattern = re.compile(
    r"iteration\s+(\d+)/\s*(\d+)\s*\|"
    r".*?elapsed time per iteration \(ms\):\s*([\d.]+)\s*\|"
    r".*?throughput per GPU \(TFLOP/s/GPU\):\s*([\d.]+)\s*\|"
    r".*?global batch size:\s*(\d+)\s*\|"
    r".*?lm loss:\s*([\d.Ee+-]+)\s*\|"
    r"(?:.*?load_balancing_loss:\s*([\d.Ee+-]+)\s*\|)?"
    r".*?number of skipped iterations:\s*(\d+)\s*\|"
    r".*?number of nan iterations:\s*(\d+)\s*\|"
)
val_pattern = re.compile(
    r"validation loss at iteration\s+(\d+)(?:\s+on validation set)?\s*\|"
    r"\s*lm loss value:\s*([\d.Ee+-]+)\s*\|\s*lm loss PPL:\s*([\d.Ee+-]+)"
)

steps = []
for m in step_pattern.finditer(logs):
  steps.append({
      "iter": int(m.group(1)),
      "total": int(m.group(2)),
      "ms": float(m.group(3)),
      "tflops": float(m.group(4)),
      "gbs": int(m.group(5)),
      "loss": float(m.group(6)),
      "aux_loss": float(m.group(7)) if m.group(7) else None,
      "skipped": int(m.group(8)),
      "nan": int(m.group(9)),
  })

vals = [(m.group(1), float(m.group(2)), float(m.group(3))) for m in val_pattern.finditer(logs)]

if not steps:
  print("ERROR: No Megatron-LM iteration metrics found in logs.", file=sys.stderr)
  sys.exit(1)

warmup = 5
steady = [s for s in steps if s["iter"] > warmup] or steps
seq_len = 4096
world_size = 16
tokens_per_step = steady[0]["gbs"] * seq_len

mean_ms = statistics.mean(s["ms"] for s in steady)
p50_ms = statistics.median(s["ms"] for s in steady)
min_ms = min(s["ms"] for s in steady)
mean_tflops = statistics.mean(s["tflops"] for s in steady)
steady_max_tflops = max(s["tflops"] for s in steady)
max_tflops = max(s["tflops"] for s in steps)
cluster_tps = tokens_per_step / (mean_ms / 1000.0)
peak_cluster_tps = tokens_per_step / (min_ms / 1000.0)
gpu_tps = cluster_tps / world_size
total_skipped = sum(s["skipped"] for s in steps)
total_nan = sum(s["nan"] for s in steps)

print("=== Mixtral 8x7B A4 (16x B200) Megatron-LM Benchmark Summary ===")
print(f"Total iterations parsed       : {len(steps)} (steady-state: iters {steady[0]['iter']}..{steady[-1]['iter']})")
print(f"Tokens per iteration          : {tokens_per_step:,} (GBS={steady[0]['gbs']}, seq_len={seq_len})")
print(f"Mean step time (steady-state) : {mean_ms:.1f} ms (median: {p50_ms:.1f} ms, min: {min_ms:.1f} ms)")
print(f"Per-GPU compute throughput    : {mean_tflops:.1f} TFLOP/s/GPU (steady-state peak: {steady_max_tflops:.1f}, max: {max_tflops:.1f} TFLOP/s/GPU)")
print(f"Cluster token throughput      : {cluster_tps:,.1f} tokens/sec ({gpu_tps:,.1f} tokens/sec/GPU; peak: {peak_cluster_tps:,.1f} tokens/sec)")
print(f"Training lm loss              : {steps[0]['loss']:.4f} (iter {steps[0]['iter']}) -> {steps[-1]['loss']:.4f} (iter {steps[-1]['iter']})")
for tag, vloss, vppl in vals:
  print(f"Validation (iter {tag:>2})          : lm loss = {vloss:.4f}, PPL = {vppl:.2f}")
print(f"Numerical stability           : skipped_iters={total_skipped}, nan_iters={total_nan}")

if total_nan > 0:
  print("ERROR: NaN iterations detected during training.", file=sys.stderr)
  sys.exit(1)
EOF
# [END hypercomputer_gpu_train_mixtral_8x7b_benchmark_summary]

echo "Verifying dataset and sharded torch_dist checkpoints in Cloud Storage..."
# [START hypercomputer_gpu_train_mixtral_8x7b_verify_checkpoints]
export TRAINING_BUCKET="$(kubectl get pv -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-training")].spec.csi.volumeHandle}')"
export CHECKPOINT_BUCKET="$(kubectl get pv -o jsonpath='{.items[?(@.spec.storageClassName=="gcsfusecsi-checkpointing")].spec.csi.volumeHandle}')"
echo "Training bucket:   gs://${TRAINING_BUCKET}"
echo "Checkpoint bucket: gs://${CHECKPOINT_BUCKET}"
gcloud storage ls "gs://${TRAINING_BUCKET}/dataset/"
gcloud storage ls "gs://${CHECKPOINT_BUCKET}/mixtral-8x7b/"
gcloud storage ls "gs://${CHECKPOINT_BUCKET}/mixtral-8x7b/iter_0000050/" | head -n 20
# [END hypercomputer_gpu_train_mixtral_8x7b_verify_checkpoints]
