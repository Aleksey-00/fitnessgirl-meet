#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
VPS=root@134.0.113.50

# ensure unix scripts locally
sed -i 's/\r$//' "$ROOT/docker/entrypoint.sh" "$ROOT/docker/entrypoint-tools.sh" 2>/dev/null || true

rsync -az \
  --exclude '.git' --exclude 'node_modules' --exclude '.nuxt' --exclude '.output' \
  --exclude '.env' --exclude 'models' --exclude '*.log' --exclude 'scripts/_*.*' \
  -e "ssh -F /dev/null -o StrictHostKeyChecking=no -i $SSH_KEY" \
  "$ROOT/" "$VPS:/opt/fitnessgirl-meet/"

ssh -F /dev/null -o StrictHostKeyChecking=no -i "$SSH_KEY" "$VPS" 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
set -a; source .env; set +a
# belt-and-suspenders on the host copy
sed -i 's/\r$//' docker/entrypoint.sh docker/entrypoint-tools.sh scripts/daily-indexer-loop.sh || true
# force rebuild entrypoint layer
docker compose build --no-cache app
docker compose up -d app
for i in $(seq 1 40); do
  st=$(docker inspect -f '{{.State.Health.Status}}' fitnessgirl-meet-app-1 2>/dev/null || echo missing)
  echo "health=$st ($i)"
  if [[ "$st" == "healthy" ]]; then
    curl -fsS http://127.0.0.1:3000/api/health; echo
    break
  fi
  if [[ "$st" == "unhealthy" || "$st" == "restarting" ]]; then
    docker compose logs --tail=30 app || true
  fi
  sleep 5
done
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  'SELECT migration_name FROM "_prisma_migrations" ORDER BY finished_at;'
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='User' AND column_name='gender';"
REMOTE
