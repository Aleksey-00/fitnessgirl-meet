#!/usr/bin/env bash
set -euo pipefail
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
VPS="${FG_VPS:-root@134.0.113.50}"
ROOT="/mnt/c/projects/fitnessgirl-meet"
if [[ ! -f "$SSH_KEY" ]]; then
  SSH_KEY=/mnt/c/Users/aazor/.ssh/id_rsa
fi

python3 - <<PY
from pathlib import Path
for rel in [
    "scripts/_vps-rebuild-app.sh",
    "scripts/_run-vps-rebuild.sh",
    "docker/entrypoint.sh",
    "docker/entrypoint-tools.sh",
    "Dockerfile",
]:
    p = Path("/mnt/c/projects/fitnessgirl-meet") / rel
    if p.exists():
        p.write_bytes(p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
PY

echo "==> prepare prisma client overlay (schema-matching JS)"
cd "$ROOT"
npx prisma generate >/tmp/fg-prisma-gen.log 2>&1 || {
  echo "WARN: local prisma generate failed; see /tmp/fg-prisma-gen.log"
  cat /tmp/fg-prisma-gen.log | tail -30
}
rm -rf _prisma_client_overlay
mkdir -p _prisma_client_overlay
if [ -f node_modules/.prisma/client/schema.prisma ]; then
  for f in index.js index.d.ts index-browser.js client.js client.d.ts default.js default.d.ts \
           edge.js edge.d.ts wasm.js wasm.d.ts query_engine_bg.js query_engine_bg.wasm \
           wasm-edge-light-loader.mjs wasm-worker-loader.mjs package.json schema.prisma; do
    [ -f "node_modules/.prisma/client/$f" ] && cp "node_modules/.prisma/client/$f" _prisma_client_overlay/
  done
  grep -q invId _prisma_client_overlay/schema.prisma
  echo "overlay ready ($(ls _prisma_client_overlay | wc -l) files)"
else
  echo "WARN: no local .prisma/client — overlay skipped"
fi

echo "==> sync"
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
  "$ROOT/" "$VPS:/opt/fitnessgirl-meet/"

echo "==> upload rebuild script"
scp -F /dev/null -o StrictHostKeyChecking=no -i "$SSH_KEY" \
  "$ROOT/scripts/_vps-rebuild-app.sh" "$VPS:/tmp/fg-rebuild.sh"

echo "==> remote rebuild"
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=15 \
  -i "$SSH_KEY" "$VPS" "bash /tmp/fg-rebuild.sh"

echo LOCAL_DONE
