#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
set -a; source .env; set +a

echo "== build app (no cache for prisma/pages)"
docker compose build app
echo "== up app"
docker compose up -d app
echo "== wait healthy"
for i in $(seq 1 36); do
  st=$(docker inspect -f '{{.State.Health.Status}}' fitnessgirl-meet-app-1 2>/dev/null || echo missing)
  echo "health=$st ($i)"
  if [[ "$st" == "healthy" ]]; then
    curl -fsS http://127.0.0.1:3000/api/health; echo
    break
  fi
  sleep 5
done

echo "== migrations applied?"
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  'SELECT migration_name, finished_at FROM "_prisma_migrations" ORDER BY finished_at;'

echo "== gender column?"
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "\d \"User\"" | head -40
REMOTE
