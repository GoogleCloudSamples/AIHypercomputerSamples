#!/bin/bash

set -euo pipefail

source 0_env.sh

echo "Applying network mappings..."
envsubst < network-mapping.yaml | kubectl apply -f -

echo "Network mappings applied."
