#!/usr/bin/env bash
# One-shot: male-only daily index from home IP (Docker Desktop safe).
set -euo pipefail
ROOT=/mnt/c/projects/fitnessgirl-meet
cd "$ROOT"
sed -i 's/\r$//' scripts/_run-home-indexer-dockerdesk.sh scripts/index-vk.ts
export VK_REQUEST_DELAY_MS="${VK_REQUEST_DELAY_MS:-8000}"
export FG_DAILY_LIMIT="${FG_DAILY_LIMIT:-60}"
export VK_FLOOD_COOLDOWN_MS="${VK_FLOOD_COOLDOWN_MS:-300000}"
echo "[$(date -Iseconds)] male-only daily start limit=$FG_DAILY_LIMIT delay=${VK_REQUEST_DELAY_MS}ms"
bash scripts/_run-home-indexer-dockerdesk.sh --daily --sex=male
echo "[$(date -Iseconds)] male-only daily done"
