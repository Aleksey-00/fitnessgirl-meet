#!/usr/bin/env bash
set -euo pipefail
ROOT=/mnt/c/projects/fitnessgirl-meet
cd "$ROOT"
LOG="$ROOT/scripts/_home-daily-retry.log"
{
  echo "[$(date -Iseconds)] cool-down 90m then daily index"
  sleep 5400
  echo "[$(date -Iseconds)] starting retry"
  export VK_REQUEST_DELAY_MS=10000
  export FG_DAILY_LIMIT=80
  sed -i 's/\r$//' scripts/_run-home-indexer-dockerdesk.sh
  bash scripts/_run-home-indexer-dockerdesk.sh --daily
  echo "[$(date -Iseconds)] EXIT:$?"
} >"$LOG" 2>&1
