#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
python3 - <<'PY'
from pathlib import Path
raw = Path('.env').read_text(encoding='utf-8', errors='replace')
keys = {}
for line in raw.splitlines():
    if not line.strip() or line.strip().startswith('#') or '=' not in line:
        continue
    k, v = line.split('=', 1)
    keys[k] = v.strip().strip('"').strip("'")
tok = keys.get('VK_ACCESS_TOKEN', '')
print('VK_ACCESS_TOKEN_len', len(tok))
print('VK_ACCESS_TOKEN_prefix', tok[:16] if tok else '')
for k in sorted(keys):
    if 'VK' in k.upper() or 'CLIENT' in k.upper() or 'APP' in k.upper():
        if 'TOKEN' in k.upper() or 'SECRET' in k.upper() or 'PASSWORD' in k.upper():
            print(f'{k}=<len {len(keys[k])}>')
        else:
            print(f'{k}={keys[k][:80]}')
PY
REMOTE
