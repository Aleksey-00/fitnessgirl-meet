#!/usr/bin/env bash
# Daily VK index for BOTH sexes → production Postgres (via home IP + SSH tunnel).
# Token is IP-bound; do not run this on the VPS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export FG_DAILY_LIMIT="${FG_DAILY_LIMIT:-100}"
export VK_REQUEST_DELAY_MS="${VK_REQUEST_DELAY_MS:-1500}"
export VK_INDEX_SEX=both
# Same-day re-runs: bump salt so name/age shards rotate to fresh people.
export VK_INDEX_SALT="${VK_INDEX_SALT:-$(date +%s)}"

sed -i 's/\r$//' "$ROOT/scripts/_run-home-indexer-dockerdesk.sh" "$ROOT/scripts/index-vk.ts" 2>/dev/null || true

echo "[$(date -Iseconds)] home daily BOTH sexes start limit=${FG_DAILY_LIMIT} delay=${VK_REQUEST_DELAY_MS}ms salt=${VK_INDEX_SALT}"
bash "$ROOT/scripts/_run-home-indexer-dockerdesk.sh" --daily --sex=both
echo "[$(date -Iseconds)] home daily BOTH sexes done"
