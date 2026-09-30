#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'python3 - <<'"'"'PY'"'"'
from pathlib import Path
raw = Path("/opt/fitnessgirl-meet/.env").read_text(encoding="utf-8", errors="replace")
for line in raw.splitlines():
    if line.startswith("VK_ACCESS_TOKEN="):
        v = line.split("=", 1)[1].strip()
        if (v.startswith("\"") and v.endswith("\"")) or (v.startswith("'\''") and v.endswith("'\''")):
            v = v[1:-1]
        v = v.replace("\\\"", "\"").replace("\\\\", "\\")
        print(v)
        break
else:
    raise SystemExit("VK_ACCESS_TOKEN not found")
PY'
