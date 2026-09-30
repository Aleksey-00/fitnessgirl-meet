#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
python3 - <<'PY'
from pathlib import Path
import re, json, urllib.parse, urllib.request
raw = Path('.env').read_text(encoding='utf-8', errors='replace')
token = ''
for line in raw.splitlines():
    if line.startswith('VK_ACCESS_TOKEN='):
        v = line.split('=',1)[1].strip()
        if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
        token = v.replace('\\"','"').replace('\\\\','\\')
        break
print('len', len(token))
print('prefix', token[:8] if token else '')
print('suffix', token[-8:] if token else '')
print('has_space', ' ' in token)
print('has_newline', '\n' in token or '\r' in token)
# try users.get from VPS (expect fail if IP-bound OR invalid)
q=urllib.parse.urlencode({"v":"5.199","access_token":token})
try:
    data=json.load(urllib.request.urlopen("https://api.vk.com/method/users.get?"+q, timeout=20))
    print('vk_response', data)
except Exception as e:
    print('vk_http_error', e)
PY
REMOTE
