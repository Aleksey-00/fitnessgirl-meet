#!/usr/bin/env python3
from pathlib import Path

content = r'''#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$HOME/.ssh/id_rsa" root@134.0.113.50 "bash -s" <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo === files ===
ls -la pages/catalog.vue prisma/migrations/20260928090000_user_gender/migration.sql server/api/profiles/index.get.ts
echo === grep api ===
grep -n parseCatalogGender server/api/profiles/index.get.ts | head -20
grep -n gender server/api/profiles/index.get.ts | head -20
echo === grep ui ===
grep -nE "Девушки|Парни|gender" pages/catalog.vue | head -30
echo === health ===
curl -fsS http://127.0.0.1:3000/api/health; echo
echo === female ===
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=female" | head -c 400; echo
echo === male ===
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=male" | head -c 400; echo
echo === docker ===
docker compose ps
REMOTE
'''

out = Path('/tmp/_verify-prod.sh')
out.write_text(content, newline='\n')
print('written', out, 'bytes', out.stat().st_size)
