#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VPS="${FG_VPS:-root@134.0.113.50}"
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
REMOTE_DIR="${FG_PROJECT_DIR:-/opt/fitnessgirl-meet}"

sed -i 's/\r$//' "$ROOT/docker/entrypoint.sh" "$ROOT/docker/entrypoint-tools.sh" 2>/dev/null || true

SSH=(ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=15 -i "$SSH_KEY" "$VPS")

echo "==> sync to $VPS:$REMOTE_DIR"
rsync -az \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.nuxt' \
  --exclude '.output' \
  --exclude '.env' \
  --exclude 'models' \
  --exclude '*.log' \
  --exclude 'scripts/_*.sh' \
  --exclude 'scripts/_*.ps1' \
  --exclude 'scripts/_*.mjs' \
  --exclude 'scripts/_*.js' \
  --exclude 'scripts/_*.ts' \
  -e "ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -i $SSH_KEY" \
  "$ROOT/" "$VPS:$REMOTE_DIR/"

echo "==> remote migrate + rebuild"
"${SSH[@]}" 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
sed -i 's/\r$//' docker/entrypoint.sh docker/entrypoint-tools.sh scripts/daily-indexer-loop.sh 2>/dev/null || true
set -a
# shellcheck disable=SC1091
source .env
set +a
echo "== migrate"
docker compose run --rm --no-deps -T --entrypoint sh app -c "npx prisma migrate deploy" </dev/null
echo "== rebuild app"
docker compose up -d --build app
echo "== wait health"
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    echo HEALTH_OK
    curl -fsS http://127.0.0.1:3000/api/health
    echo
    break
  fi
  sleep 5
  echo "wait $i..."
done
docker compose ps
echo "== smoke gender filter"
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=1&gender=female' | head -c 180; echo
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=1&gender=male' | head -c 180; echo
REMOTE

echo DONE_DEPLOY
