#!/bin/bash
#
#   Copyright 2026 Google LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail

RELEASE_NAME="${USER}-serving-llama-4-a4"
TARGET_MODEL="${MODEL_ID}"

echo "=============================================================================="
echo "Running Llama 4 Scout Serving Validation Job on 8x B200 (A4)..."
echo "Target Release: ${RELEASE_NAME}"
echo "Target Model:   ${TARGET_MODEL}"
echo "=============================================================================="

# 1. Searching the active Pod by name prefix
POD_NAME=$(kubectl get pods -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep "^${RELEASE_NAME}-" | head -n 1 || true)

if [[ -z "$POD_NAME" ]]; then
    echo "ERROR: Could not find any active Pod for release '${RELEASE_NAME}'."
    exit 1
fi

echo "1/4 [OK] Found target Pod: ${POD_NAME}"

# 2. Checking the status of a Pod in K8s
POD_STATUS=$(kubectl get pod "${POD_NAME}" -o jsonpath='{.status.phase}')
if [[ "$POD_STATUS" != "Running" ]]; then
    echo "ERROR: Pod ${POD_NAME} is in state '${POD_STATUS}', expected 'Running'."
    exit 1
fi

echo "2/4 [OK] Pod state is Running."

# 3. Checking the /health endpoint of vLLM inside the container
echo "3/4 [OK] Testing vLLM Health endpoint inside container..."
HEALTH_CHECK=$(kubectl exec "${POD_NAME}" -c serving -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health || true)

if [[ "$HEALTH_CHECK" != "200" ]]; then
    echo "ERROR: vLLM Health check failed with HTTP code: ${HEALTH_CHECK}"
    exit 1
fi
echo "vLLM API Health Status: 200 OK"

# 4. Executing a text query with time measurement
echo "4/4 [OK] Submitting test Chat Completion request to Llama 4..."
echo "=============================================================================="

VALIDATION_PAYLOAD=$(cat <<EOF
{
  "model": "${TARGET_MODEL}",
  "messages": [
    {"role": "user", "content": "Hello Llama 4! Give me a short 3-word technical greeting."}
  ],
  "max_tokens": 30,
  "temperature": 0.1
}
EOF
)

START_TIME=$(date +%s%N)

RESPONSE=$(kubectl exec "${POD_NAME}" -c serving -- curl -s -X POST http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "${VALIDATION_PAYLOAD}")

END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

if echo "$RESPONSE" | grep -q "chat.completion"; then
    echo ""
    echo "== ALL SYSTEMS GO: MODEL RESPONDED SUCCESSFULLY =="
    echo "Execution Time: ${DURATION_MS} ms"
    echo "------------------------------------------------------------------------------"

    # 5. Extracting the plain content of the response
    MODEL_OUTPUT=$(kubectl exec "${POD_NAME}" -c serving -- python3 -c "import sys, json; print(json.loads('''$RESPONSE''')['choices'][0]['message']['content'])" 2>/dev/null || echo "$RESPONSE")

    echo "Model Output: ${MODEL_OUTPUT}"
    echo "=============================================================================="
    echo "SUCCESS: Llama 4 Scout is operational and ready to serve traffic on B200 GPUs!"
else
    echo "ERROR: Validation inference failed."
    echo "Raw Response: ${RESPONSE}"
    exit 1
fi
