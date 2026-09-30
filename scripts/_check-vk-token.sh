#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo "== VK_ vars (masked) =="
grep -E '^VK_' .env | sed 's/=.*/=***/' || true
echo "== token length =="
python3 - <<'PY'
from pathlib import Path
raw = Path('.env').read_text(encoding='utf-8', errors='replace')
for line in raw.splitlines():
    if line.startswith('VK_ACCESS_TOKEN='):
        print(len(line.split('=',1)[1].strip().strip('"').strip("'")))
        break
else:
    print(0)
PY
docker ps -a --filter name=indexer --format '{{.Names}} {{.Status}}' || true
REMOTE
