#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 bash -s <<'EOF'
set -euo pipefail
echo -n "vps_ip="
curl -4 -sS --max-time 10 https://api.ipify.org || echo fail
echo
echo -n "tg_root="
curl -4 -sS --max-time 15 -o /dev/null -w "%{http_code} time=%{time_total}\n" https://api.telegram.org/ || echo fail
TOKEN=$(python3 - <<'PY'
from pathlib import Path
for line in Path('/opt/fitnessgirl-meet/.env').read_text().splitlines():
  if line.startswith('TELEGRAM_BOT_TOKEN='):
    print(line.split('=',1)[1].strip().strip('"').strip("'"))
    break
PY
)
echo -n "tg_getMe="
curl -4 -sS --max-time 20 "https://api.telegram.org/bot${TOKEN}/getMe" | head -c 300
echo
EOF
