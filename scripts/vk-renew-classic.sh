#!/usr/bin/env bash
# Save classic vk1.a token from blank.html redirect URL, then verify users.search.
# Usage:
#   echo 'https://oauth.vk.com/blank.html#access_token=vk1.a....' > /tmp/fg-vk-classic-url.txt
#   bash scripts/vk-renew-classic.sh
# Or:
#   bash scripts/vk-renew-classic.sh 'https://oauth.vk.com/blank.html#access_token=...'
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OAUTH_URL="$(tr -d '\r\n' <"$ROOT/scripts/vk-oauth-classic.url")"

if [[ $# -ge 1 ]]; then
  printf '%s' "$1" > /tmp/fg-vk-classic-url.txt
fi

if [[ ! -s /tmp/fg-vk-classic-url.txt ]]; then
  echo "Missing /tmp/fg-vk-classic-url.txt"
  echo "Open in Cursor browser, then save the redirect URL:"
  echo "  $OAUTH_URL"
  exit 2
fi

sed -i 's/\r$//' "$ROOT/scripts/_vk-save-classic.sh" 2>/dev/null || true
bash "$ROOT/scripts/_vk-save-classic.sh"
echo "Renewed from classic OAuth (client_id=54762499 blank.html)."
