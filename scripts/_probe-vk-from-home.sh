#!/usr/bin/env bash
set -euo pipefail
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
VPS="${FG_VPS:-root@134.0.113.50}"
IP="$(curl -sS --max-time 10 https://api.ipify.org || true)"
echo "==> home public IP: $IP"
export VK_ACCESS_TOKEN="$(
  ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VPS" \
    "python3 -c \"import re; from pathlib import Path; e=Path('/opt/fitnessgirl-meet/.env').read_text(); m=re.search(r'(?m)^VK_ACCESS_TOKEN=(.*)\$', e); t=(m.group(1).strip().strip(chr(34)).strip(chr(39)) if m else ''); print(t)\""
)"
echo "token_len ${#VK_ACCESS_TOKEN}"
python3 - <<'PY'
import os, urllib.request, urllib.parse
token = os.environ.get("VK_ACCESS_TOKEN", "")
q = urllib.parse.urlencode({"v": "5.199", "access_token": token})
url = "https://api.vk.com/method/users.get?" + q
try:
    with urllib.request.urlopen(url, timeout=20) as r:
        print("FROM_HOME", r.read().decode()[:400])
except Exception as e:
    print("FROM_HOME_ERR", e)
PY
unset VK_ACCESS_TOKEN
