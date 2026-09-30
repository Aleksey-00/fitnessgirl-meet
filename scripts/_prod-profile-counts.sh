#!/bin/bash
set -euo pipefail
cd /opt/fitnessgirl-meet
echo '== compose =='
docker compose ps
echo '== profile counts =='
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c 'SELECT "photoGender", "isHidden", count(*) FROM "Profile" GROUP BY 1,2 ORDER BY 1,2;'
echo '== token len =='
python3 -c "
from pathlib import Path
env={}
for line in Path('.env').read_text().splitlines():
  if not line.strip() or line.strip().startswith('#') or '=' not in line: continue
  k,v=line.split('=',1); env[k]=v.strip().strip(chr(34)).strip(chr(39))
print('VK_ACCESS_TOKEN_len', len(env.get('VK_ACCESS_TOKEN','')))
print('POSTGRES_USER', env.get('POSTGRES_USER'))
"
echo DONE_COUNTS
