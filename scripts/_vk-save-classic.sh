#!/usr/bin/env bash
set -euo pipefail
# Reads token from /tmp/fg-vk-classic-url.txt (full blank.html#... URL)
python3 - <<'PY'
from pathlib import Path
from urllib.parse import urlparse, parse_qs
raw = Path('/tmp/fg-vk-classic-url.txt').read_text().strip()
# hash fragment
frag = raw.split('#',1)[1] if '#' in raw else raw
q = parse_qs(frag)
tok = q.get('access_token',[''])[0]
exp = q.get('expires_in',[''])[0]
uid = q.get('user_id',[''])[0]
if not tok.startswith('vk1.'):
    raise SystemExit(f'bad token prefix: {tok[:20]}')
Path('/tmp/fg-vk-access-token.txt').write_text(tok)
print('token_len', len(tok))
print('expires_in', exp)
print('user_id', uid)
PY

python3 - <<'PY'
import json, urllib.parse, urllib.request
from pathlib import Path
token=Path('/tmp/fg-vk-access-token.txt').read_text().strip()
for method, extra in [
  ('users.get', {}),
  ('users.search', {'q':'а','count':'1','city':'1','sex':'1','age_from':'18','age_to':'35','has_photo':'1'}),
]:
  q=urllib.parse.urlencode({'v':'5.199','access_token':token, **extra})
  data=json.load(urllib.request.urlopen(f'https://api.vk.com/method/{method}?{q}', timeout=25))
  err=data.get('error')
  if err:
    print(method, 'ERR', err.get('error_code'), err.get('error_msg'))
  else:
    resp=data.get('response')
    if isinstance(resp, dict) and 'count' in resp:
      print(method, 'OK count=', resp.get('count'), 'items=', len(resp.get('items') or []))
    else:
      print(method, 'OK', str(resp)[:160])
PY

TOKEN_B64="$(python3 -c 'import base64,pathlib; print(base64.b64encode(pathlib.Path("/tmp/fg-vk-access-token.txt").read_bytes()).decode())')"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  "TOKEN_B64='${TOKEN_B64}' python3 - <<'PY'
import base64, pathlib, re, os
token = base64.b64decode(os.environ['TOKEN_B64']).decode()
path = pathlib.Path('/opt/fitnessgirl-meet/.env')
text = path.read_text(encoding='utf-8', errors='replace')
line = 'VK_ACCESS_TOKEN=' + token
if re.search(r'^VK_ACCESS_TOKEN=.*$', text, flags=re.M):
    text = re.sub(r'^VK_ACCESS_TOKEN=.*$', line, text, count=1, flags=re.M)
else:
    text = text.rstrip() + '\n' + line + '\n'
path.write_text(text, encoding='utf-8')
print('saved_to_vps_len', len(token))
print('prefix', token[:8])
PY"
echo DONE
