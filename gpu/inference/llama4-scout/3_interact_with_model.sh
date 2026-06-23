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


kubectl port-forward service/llm-service 8000:8000 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for port forwarding to be ready..."
MAX_WAIT_SECONDS=15
SECONDS_WAITED=0

while ! curl -s "http://127.0.0.1:8000/health" >/dev/null; do
    if ! kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
        echo "Error: Port forwarding failed to start or died unexpectedly." >&2
        exit 1
    fi
    
    if [ "$SECONDS_WAITED" -ge "$MAX_WAIT_SECONDS" ]; then
        echo "Error: Timed out after ${MAX_WAIT_SECONDS}s waiting for port 8000." >&2
        exit 1
    fi
    
    sleep 1
    ((SECONDS_WAITED++))
done

echo "[$(date)] ==================== Sending inference request to Llama 4... ===================="
# [START hypercomputer_gpu_infer_llama4scout_interact]
curl http://127.0.0.1:8000/v1/chat/completions \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{
       "model": "meta-llama/Llama-4-Scout-17B-16E-Instruct",
       "messages": [
         {
           "role": "user",
           "content": "Describe a sailboat in one short sentence?"
         }
       ]
     }' | jq .
# [END hypercomputer_gpu_infer_llama4scout_interact]
echo "[$(date)] ==================== Iteration was completed. ===================="
