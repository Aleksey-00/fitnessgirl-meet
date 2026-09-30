#!/usr/bin/env bash
set -euo pipefail
ROOT=/mnt/c/projects/fitnessgirl-meet
sed -i 's/\r$//' "$ROOT/scripts/run-home-indexer.sh" "$ROOT/scripts/index-vk.ts"
echo "==> cool-down 15m for VK flood, then daily index (delay=3s)"
sleep 900
export VK_REQUEST_DELAY_MS=3000
bash "$ROOT/scripts/run-home-indexer.sh" --daily
