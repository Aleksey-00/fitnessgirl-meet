#!/usr/bin/env bash
set -euo pipefail
ROOT=/mnt/c/projects/fitnessgirl-meet
cd "$ROOT"
LOG="$ROOT/scripts/_male-at-2200.log"
TARGET_LOCAL="${FG_RUN_AT:-22:00}"
{
  now_epoch=$(date +%s)
  run_epoch=$(date -d "today ${TARGET_LOCAL}" +%s)
  if [[ "$run_epoch" -le "$now_epoch" ]]; then
    run_epoch=$(date -d "tomorrow ${TARGET_LOCAL}" +%s)
  fi
  wait_s=$((run_epoch - now_epoch))
  echo "[$(date -Iseconds)] scheduled male-only daily at $(date -d "@$run_epoch" -Iseconds) (sleep ${wait_s}s)"
  sleep "$wait_s"
  echo "[$(date -Iseconds)] starting male-only daily"
  sed -i 's/\r$//' scripts/_run-home-indexer-dockerdesk.sh scripts/index-vk.ts scripts/_run-male-daily.sh
  export VK_REQUEST_DELAY_MS="${VK_REQUEST_DELAY_MS:-10000}"
  export FG_DAILY_LIMIT="${FG_DAILY_LIMIT:-60}"
  export VK_FLOOD_COOLDOWN_MS="${VK_FLOOD_COOLDOWN_MS:-600000}"
  bash scripts/_run-male-daily.sh
  echo "[$(date -Iseconds)] EXIT:$?"
} >"$LOG" 2>&1
