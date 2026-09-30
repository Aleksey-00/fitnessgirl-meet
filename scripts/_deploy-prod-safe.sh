#!/usr/bin/env bash
set -euo pipefail
ROOT="/mnt/c/projects/fitnessgirl-meet"
VPS="root@134.0.113.50"
SSH_KEY="$HOME/.ssh/id_rsa"
REMOTE_DIR="/opt/fitnessgirl-meet"

python3 - <<'PY'
from pathlib import Path
for rel in ["docker/entrypoint.sh", "docker/entrypoint-tools.sh"]:
    p = Path("/mnt/c/projects/fitnessgirl-meet") / rel
    if p.exists():
        data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        p.write_bytes(data)
        print("lf-fixed", p)
PY

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
  --exclude 'scripts/_*.py' \
  -e "ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -i $SSH_KEY" \
  "$ROOT/" "$VPS:$REMOTE_DIR/"

echo "==> remote migrate + rebuild"
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=15 -i "$SSH_KEY" "$VPS" "bash -s" <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
python3 - <<'PY'
from pathlib import Path
for rel in ["docker/entrypoint.sh", "docker/entrypoint-tools.sh", "scripts/daily-indexer-loop.sh"]:
    p = Path(rel)
    if p.exists():
        data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        p.write_bytes(data)
PY
echo "== migrate"
docker compose run --rm --no-deps --entrypoint sh app -c "npx prisma migrate deploy"
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
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=female" | head -c 200; echo
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=male" | head -c 200; echo
REMOTE

echo DONE_DEPLOY
