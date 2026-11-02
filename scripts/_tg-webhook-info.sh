#!/usr/bin/env bash
set -euo pipefail
SSH=(ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50)
TOKEN="$("${SSH[@]}" "python3 -c \"import re; from pathlib import Path; e=Path('/opt/fitnessgirl-meet/.env').read_text(); m=re.search(r'(?m)^TELEGRAM_BOT_TOKEN=(.*)\$', e); print((m.group(1).strip().strip(chr(34)).strip(chr(39)) if m else ''))\"")"
echo "token_len=${#TOKEN}"
python3 - <<PY
import json, urllib.request, os
token = """$TOKEN"""
for method in ("getWebhookInfo", "getMe"):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = json.load(urllib.request.urlopen(url, timeout=20))
    print(method, json.dumps(data, ensure_ascii=False)[:800])
PY
