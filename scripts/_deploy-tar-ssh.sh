#!/usr/bin/env bash
set -euo pipefail
ROOT=/c/projects/fitnessgirl-meet
VPS=root@134.0.113.50
KEY=/c/Users/aazor/.ssh/id_rsa
REMOTE=/opt/fitnessgirl-meet
SSH=(ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=15 -i "$KEY" "$VPS")

echo "==> LF fix local entrypoints"
sed -i 's/\r$//' "$ROOT/docker/entrypoint.sh" "$ROOT/docker/entrypoint-tools.sh" 2>/dev/null || true

echo "==> tar sync to $VPS:$REMOTE"
cd "$ROOT"
tar --exclude='.git' --exclude='node_modules' --exclude='.nuxt' --exclude='.output' \
  --exclude='.env' --exclude='models' --exclude='*.log' \
  --exclude='scripts/_*.sh' --exclude='scripts/_*.ps1' --exclude='scripts/_*.mjs' \
  --exclude='scripts/_*.js' --exclude='scripts/_*.ts' --exclude='scripts/_*.cjs' \
  --exclude='scripts/_*.log' \
  -czf - . | "${SSH[@]}" "mkdir -p $REMOTE && tar -xzf - -C $REMOTE"

echo "==> remote migrate + rebuild"
"${SSH[@]}" 'bash -s' <<'REMOTE_SCRIPT'
set -euo pipefail
cd /opt/fitnessgirl-meet
sed -i 's/\r$//' docker/entrypoint.sh docker/entrypoint-tools.sh scripts/daily-indexer-loop.sh 2>/dev/null || true
set -a
# shellcheck disable=SC1091
source .env
set +a
echo "== migrate"
docker compose run --rm --no-deps app npx prisma migrate deploy
echo "== rebuild app"
docker compose up -d --build app
echo "== wait health"
for i in $(seq 1 40); do
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
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=1&gender=female' | head -c 220; echo
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=1&gender=male' | head -c 220; echo
REMOTE_SCRIPT
echo DONE_DEPLOY
