#!/usr/bin/env bash
set -euo pipefail
CLIENT_ID=54762470
REDIRECT='https://fitnessgirl-meet.ru'
VERIFIER="$(cat /tmp/fg-vk-verifier.txt)"
# Prefer URL from file if provided; else args
CODE="${1:-}"
DEVICE_ID="${2:-}"
if [[ -z "$CODE" || -z "$DEVICE_ID" ]]; then
  echo "usage: $0 <code> <device_id>" >&2
  exit 1
fi

echo "==> exchange code for tokens"
RESP="$(curl -sS "https://id.vk.ru/oauth2/auth" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${CODE}" \
  -d "code_verifier=${VERIFIER}" \
  -d "device_id=${DEVICE_ID}" \
  -d "redirect_uri=${REDIRECT}")"
printf '%s' "$RESP" > /tmp/fg-vk-token-resp.json
python3 - <<'PY'
import json
from pathlib import Path
data=json.loads(Path('/tmp/fg-vk-token-resp.json').read_text())
Path('/tmp/fg-vk-token-resp.keys').write_text(','.join(sorted(data.keys())))
if 'error' in data or 'error_description' in data or data.get('error'):
    print('EXCHANGE_FAIL', json.dumps(data, ensure_ascii=False)[:500])
    raise SystemExit(2)
tok=data.get('access_token') or data.get('access_token'.upper())
# VK ID may nest
if not tok and isinstance(data.get('access_token'), dict):
    tok=None
for k in ('access_token','token','accessToken'):
    if data.get(k):
        tok=data[k]
        break
if not tok:
    print('NO_ACCESS_TOKEN keys=', list(data.keys()))
    print(json.dumps(data, ensure_ascii=False)[:800])
    raise SystemExit(3)
Path('/tmp/fg-vk-access-token.txt').write_text(tok)
rt=data.get('refresh_token') or ''
if rt:
    Path('/tmp/fg-vk-refresh-token.txt').write_text(rt)
print('access_token_len', len(tok))
print('refresh_token_len', len(rt))
print('expires_in', data.get('expires_in') or data.get('expires'))
print('keys', sorted(data.keys()))
PY

TOKEN="$(cat /tmp/fg-vk-access-token.txt)"
echo "==> probe users.get / users.search from home"
python3 - <<PY
import json, urllib.parse, urllib.request
token=open('/tmp/fg-vk-access-token.txt').read().strip()
for method, extra in [
  ('users.get', {}),
  ('users.search', {'q':'а','count':'1','city':'1'}),
]:
  q=urllib.parse.urlencode({'v':'5.199','access_token':token, **extra})
  try:
    data=json.load(urllib.request.urlopen(f'https://api.vk.com/method/{method}?{q}', timeout=25))
  except Exception as e:
    print(method, 'HTTP', e)
    continue
  err=data.get('error')
  if err:
    print(method, 'ERR', err.get('error_code'), err.get('error_msg'))
  else:
    print(method, 'OK', str(data.get('response'))[:180])
PY

echo "==> save VK_ACCESS_TOKEN to VPS .env (no restart)"
# shellcheck disable=SC2029
TOKEN_B64="$(python3 -c 'import base64,pathlib; print(base64.b64encode(pathlib.Path("/tmp/fg-vk-access-token.txt").read_bytes()).decode())')"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  "TOKEN_B64='${TOKEN_B64}' python3 - <<'PY'
import base64, pathlib, re
token = base64.b64decode(__import__('os').environ['TOKEN_B64']).decode()
path = pathlib.Path('/opt/fitnessgirl-meet/.env')
text = path.read_text(encoding='utf-8', errors='replace')
line = 'VK_ACCESS_TOKEN=' + token
if re.search(r'^VK_ACCESS_TOKEN=.*$', text, flags=re.M):
    text = re.sub(r'^VK_ACCESS_TOKEN=.*$', line, text, count=1, flags=re.M)
else:
    text = text.rstrip() + '\n' + line + '\n'
path.write_text(text, encoding='utf-8')
print('saved_len', len(token))
PY"

echo "DONE"
