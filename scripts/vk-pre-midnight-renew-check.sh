#!/usr/bin/env bash
# Daily ~23:00: probe VK token; if unusable, leave a renew marker for the agent/operator.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${HOME}/fg-logs"
mkdir -p "$LOG_DIR"
MARKER="$LOG_DIR/vk-needs-renew.flag"
OAUTH_URL="$(tr -d '\r\n' <"$ROOT/scripts/vk-oauth-classic.url")"
stamp="$(date -Iseconds)"

sed -i 's/\r$//' "$ROOT/scripts/vk-ensure-fresh-token.sh" 2>/dev/null || true
chmod +x "$ROOT/scripts/vk-ensure-fresh-token.sh" 2>/dev/null || true

set +e
bash "$ROOT/scripts/vk-ensure-fresh-token.sh" >"$LOG_DIR/vk-pre-midnight-check.log" 2>&1
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  rm -f "$MARKER"
  echo "[$stamp] VK_TOKEN_OK — no renew needed" | tee -a "$LOG_DIR/vk-pre-midnight-check.log"
  echo "OK"
  exit 0
fi

if [[ "$rc" -eq 42 ]]; then
  cat >"$MARKER" <<EOF
needs_renew=1
at=$stamp
reason=vk_token_unusable
oauth_url=$OAUTH_URL
hint=Open Cursor browser → oauth URL → save blank.html#access_token= via scripts/vk-renew-classic.sh
EOF
  echo "[$stamp] VK_TOKEN_NEEDS_RENEW rc=42" | tee -a "$LOG_DIR/vk-pre-midnight-check.log"
  echo "RENEW_URL=$OAUTH_URL"
  echo "NEEDS_RENEW"
  exit 42
fi

echo "[$stamp] VK_PROBE_FAILED rc=$rc" | tee -a "$LOG_DIR/vk-pre-midnight-check.log"
exit "$rc"
