#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo "== compose cron =="
docker compose --profile cron ps -a || true
echo "== env =="
grep -E '^(VK_DAILY_LIMIT|VK_INDEX_SEX|VK_REQUEST_DELAY_MS|VK_CITY_ID|VK_ACCESS_TOKEN)=' .env \
  | sed 's/^VK_ACCESS_TOKEN=.*/VK_ACCESS_TOKEN=<set>/' || true
echo "== catalog =="
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT \"photoGender\", count(*) FILTER (WHERE NOT \"isHidden\") AS visible, count(*) AS total
   FROM \"Profile\" GROUP BY 1 ORDER BY 1;"
echo "== vk from vps =="
python3 - <<'PY'
from pathlib import Path
import json, urllib.parse, urllib.request
token=''
for line in Path('.env').read_text().splitlines():
  if line.startswith('VK_ACCESS_TOKEN='):
    token=line.split('=',1)[1].strip().strip('"').strip("'"); break
q=urllib.parse.urlencode({'v':'5.199','access_token':token,'q':'а','count':'1','city':'1','sex':'1'})
try:
  data=json.load(urllib.request.urlopen('https://api.vk.com/method/users.search?'+q, timeout=20))
  print(data)
except Exception as e:
  print('http_error', e)
PY
REMOTE
