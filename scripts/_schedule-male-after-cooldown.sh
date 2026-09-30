#!/usr/bin/env bash
# Quiet cool-down then male-only daily. Do not call VK until sleep ends.
set -euo pipefail
ROOT=/mnt/c/projects/fitnessgirl-meet
cd "$ROOT"
LOG="$ROOT/scripts/_male-after-cooldown.log"
HOURS="${FG_COOLDOWN_HOURS:-6}"
{
  echo "[$(date -Iseconds)] quiet cool-down ${HOURS}h (no VK)"
  sleep $((HOURS * 3600))
  echo "[$(date -Iseconds)] starting male-only daily"
  sed -i 's/\r$//' scripts/_run-home-indexer-dockerdesk.sh scripts/index-vk.ts
  export VK_REQUEST_DELAY_MS=12000
  export FG_DAILY_LIMIT=40
  export VK_FLOOD_COOLDOWN_MS=900000
  bash scripts/_run-home-indexer-dockerdesk.sh --daily --sex=male
  echo "[$(date -Iseconds)] EXIT:$?"
} >"$LOG" 2>&1
