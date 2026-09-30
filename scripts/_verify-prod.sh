#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo "=== local files ==="
ls -la pages/catalog.vue prisma/migrations/20260928090000_user_gender/migration.sql server/api/profiles/index.get.ts
echo "=== grep gender api ==="
grep -n "parseCatalogGender\|gender" server/api/profiles/index.get.ts | head -30
echo "=== grep catalog ui ==="
grep -n "Девушки\|Парни\|gender" pages/catalog.vue | head -30
echo "=== health ==="
curl -fsS http://127.0.0.1:3000/api/health; echo
echo "=== profiles female ==="
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=female" | head -c 400; echo
echo "=== profiles male ==="
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=male" | head -c 400; echo
echo "=== docker ps ==="
docker compose ps
echo "=== migration status ==="
docker compose run --rm --no-deps --entrypoint sh app -c "npx prisma migrate status" || true
REMOTE
