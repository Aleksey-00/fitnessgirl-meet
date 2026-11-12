#!/usr/bin/env bash
# Daily VK index for BOTH sexes → production Postgres (via home IP + SSH tunnel).
# Token is IP-bound; do not run this on the VPS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# One run at a time (systemd timer + Windows Task both may fire near midnight).
exec 8>/tmp/fg-daily-index.lock
if ! flock -n 8; then
  echo "[$(date -Iseconds)] home daily already running; skip"
  exit 0
fi

export FG_DAILY_LIMIT="${FG_DAILY_LIMIT:-100}"
export VK_REQUEST_DELAY_MS="${VK_REQUEST_DELAY_MS:-1500}"
export VK_INDEX_SEX=both
# Same-day re-runs: bump salt so name/age shards rotate to fresh people.
export VK_INDEX_SALT="${VK_INDEX_SALT:-$(date +%s)}"

sed -i 's/\r$//' "$ROOT/scripts/_run-home-indexer-dockerdesk.sh" "$ROOT/scripts/index-vk.ts" "$ROOT/scripts/vk-ensure-fresh-token.sh" 2>/dev/null || true

# If classic token is dead, renew via Google Chrome on Windows (not Cursor browser).
set +e
bash "$ROOT/scripts/vk-ensure-fresh-token.sh" >/tmp/fg-daily-token-probe.log 2>&1
probe_rc=$?
set -e
if [[ "$probe_rc" -eq 42 ]]; then
  echo "[$(date -Iseconds)] VK token dead — opening Google Chrome classic OAuth"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/vk-chrome-oauth-renew.ps1" || {
    echo "[$(date -Iseconds)] Chrome VK renew failed; abort daily index"
    exit 42
  }
elif [[ "$probe_rc" -ne 0 ]]; then
  echo "[$(date -Iseconds)] VK token probe failed rc=$probe_rc; abort daily index"
  exit "$probe_rc"
fi

echo "[$(date -Iseconds)] home daily BOTH sexes start limit=${FG_DAILY_LIMIT} delay=${VK_REQUEST_DELAY_MS}ms salt=${VK_INDEX_SALT}"
bash "$ROOT/scripts/_run-home-indexer-dockerdesk.sh" --daily --sex=both
echo "[$(date -Iseconds)] home daily BOTH sexes done"
