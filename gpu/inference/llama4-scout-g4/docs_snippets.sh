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

# Start port forwarding in background
nohup kubectl port-forward "svc/${USER}-serving-llama-4-g4-svc" 8000:8000 > /dev/null 2>&1 &

# Run curl test
curl http://localhost:8000/health

# Test inference via OpenAI-compatible Chat API
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-4-Scout-17B-16E-Instruct",
    "messages": [
      {"role": "user", "content": "Witaj! Czy jesteś gotowy do pracy na GPU G4?"}
    ],
    "max_tokens": 60,
    "temperature": 0.2
  }'

# Run stream_chat.sh test
./gpu-recipes/inference/a4/single-host-serving/vllm/stream_chat.sh \
  "What is the meaning of life?" \
  "meta-llama/Llama-4-Scout-17B-16E-Instruct"

# Run benchmark
kubectl exec -it deployment/${USER}-serving-llama-4-g4 -c serving -- \
  vllm bench serve \
    --model meta-llama/Llama-4-Scout-17B-16E-Instruct \
    --dataset-name random \
    --ignore-eos \
    --num-prompts 1100 \
    --random-input-len 1000 \
    --random-output-len 1000 \
    --port 8000 \
    --backend vllm \
    --max-concurrency 64
