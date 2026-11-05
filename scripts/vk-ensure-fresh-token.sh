#!/usr/bin/env bash
# Probe VK_ACCESS_TOKEN from VPS .env (call from home IP).
# Exit 0 = usable. Exit 42 = needs classic OAuth renew from vk-oauth-classic.url
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
VPS="${FG_VPS:-root@134.0.113.50}"
OAUTH_URL="$(tr -d '\r\n' <"$ROOT/scripts/vk-oauth-classic.url")"

export VK_ACCESS_TOKEN="$(
  ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VPS" \
    "python3 -c \"import re; from pathlib import Path; e=Path('/opt/fitnessgirl-meet/.env').read_text(); m=re.search(r'(?m)^VK_ACCESS_TOKEN=(.*)\$', e); t=(m.group(1).strip().strip(chr(34)).strip(chr(39)) if m else ''); print(t)\""
)"

if [[ -z "${VK_ACCESS_TOKEN}" ]]; then
  echo "VK_TOKEN_MISSING"
  echo "RENEW_URL=$OAUTH_URL"
  exit 42
fi

python3 - <<'PY'
import json, os, urllib.parse, urllib.request, sys
token = os.environ["VK_ACCESS_TOKEN"]
q = urllib.parse.urlencode({"v": "5.199", "access_token": token})
try:
    data = json.load(urllib.request.urlopen("https://api.vk.com/method/users.get?" + q, timeout=20))
except Exception as e:
    print("VK_PROBE_ERR", e)
    sys.exit(42)
err = data.get("error")
if not err:
    uid = (data.get("response") or [{}])[0].get("id")
    print(f"VK_TOKEN_OK user_id={uid}")
    sys.exit(0)
code = err.get("error_code")
msg = err.get("error_msg", "")
print(f"VK_TOKEN_BAD code={code} msg={msg}")
# 5 = auth failed (expired / revoked / wrong IP)
if code in (5, 15) or "expired" in msg.lower() or "invalid access_token" in msg.lower() or "another ip" in msg.lower():
    sys.exit(42)
sys.exit(2)
PY
status=$?
if [[ "$status" -eq 42 ]]; then
  echo "RENEW_URL=$OAUTH_URL"
fi
exit "$status"
