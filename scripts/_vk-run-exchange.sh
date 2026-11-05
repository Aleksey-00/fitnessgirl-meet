#!/usr/bin/env bash
set -euo pipefail
# Capture from the browser redirect URL (paste once into /tmp/fg-vk-callback-url.txt)
URL_FILE=/tmp/fg-vk-callback-url.txt
if [[ ! -f "$URL_FILE" ]]; then
  echo "missing $URL_FILE" >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
from urllib.parse import urlparse, parse_qs
url = Path('/tmp/fg-vk-callback-url.txt').read_text().strip()
q = parse_qs(urlparse(url).query)
code = q.get('code', [''])[0]
device = q.get('device_id', [''])[0]
state = q.get('state', [''])[0]
Path('/tmp/fg-vk-code.txt').write_text(code)
Path('/tmp/fg-vk-device.txt').write_text(device)
print('code_len', len(code))
print('device_len', len(device))
print('state', state)
expected = Path('/tmp/fg-vk-state.txt').read_text().strip()
print('state_ok', state == expected)
if not code or not device:
    raise SystemExit('missing code/device_id')
PY
bash /mnt/c/projects/fitnessgirl-meet/scripts/_vk-exchange-and-save.sh \
  "$(cat /tmp/fg-vk-code.txt)" \
  "$(cat /tmp/fg-vk-device.txt)"
