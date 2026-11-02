#!/usr/bin/env bash
set -euo pipefail
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
VPS="${FG_VPS:-root@134.0.113.50}"
echo "==> public IP: $(curl -sS --max-time 10 https://api.ipify.org || true)"
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VPS" 'python3 -' <<'PY'
import re, urllib.request, urllib.parse
from pathlib import Path
env = Path("/opt/fitnessgirl-meet/.env").read_text(encoding="utf-8", errors="replace")
m = re.search(r"(?m)^VK_ACCESS_TOKEN=(.*)$", env)
token = (m.group(1).strip().strip('"').strip("'") if m else "")
print("token_len", len(token))
q = urllib.parse.urlencode({"v": "5.199", "access_token": token})
url = "https://api.vk.com/method/users.get?" + q
try:
    with urllib.request.urlopen(url, timeout=20) as r:
        print("FROM_VPS", r.read().decode()[:400])
except Exception as e:
    print("FROM_VPS_ERR", e)
PY
