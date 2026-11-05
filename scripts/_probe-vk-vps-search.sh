#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 bash -s <<'REMOTE'
cd /opt/fitnessgirl-meet
python3 - <<'PY'
from pathlib import Path
import json, urllib.parse, urllib.request
token=''
for line in Path('.env').read_text().splitlines():
  if line.startswith('VK_ACCESS_TOKEN='):
    token=line.split('=',1)[1].strip().strip('"').strip("'"); break
print('token_prefix', token[:10], 'len', len(token))
for sex in ('1','2'):
  q=urllib.parse.urlencode({'v':'5.199','access_token':token,'q':'а','count':'1','city':'1','sex':sex,'has_photo':'1'})
  try:
    data=json.load(urllib.request.urlopen('https://api.vk.com/method/users.search?'+q, timeout=25))
  except Exception as e:
    print('sex', sex, 'HTTP', e); continue
  err=data.get('error')
  if err: print('sex', sex, 'ERR', err.get('error_code'), err.get('error_msg'))
  else: print('sex', sex, 'OK count', data['response'].get('count'))
PY
REMOTE
