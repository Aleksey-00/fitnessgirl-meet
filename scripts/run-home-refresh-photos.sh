#!/usr/bin/env bash
# Refresh Profile.photoUrl from this machine's IP (VK token is IP-bound).
# Writes into VPS Postgres via SSH tunnel — same plumbing as run-home-indexer.sh.
#
#   ./scripts/run-home-refresh-photos.sh           # only URLs that 404
#   ./scripts/run-home-refresh-photos.sh --all     # rewrite every avatar URL
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VPS="${FG_VPS:-root@134.0.113.50}"
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
if [[ ! -f "$SSH_KEY" && -f /mnt/c/Users/aazor/.ssh/id_rsa ]]; then
  SSH_KEY=/mnt/c/Users/aazor/.ssh/id_rsa
fi
LOCAL_PORT="${FG_LOCAL_PORT:-15432}"
PROJECT_DIR="${FG_PROJECT_DIR:-/opt/fitnessgirl-meet}"

CHECK_ARGS=(--check)
if [[ "${1:-}" == "--all" ]]; then
  CHECK_ARGS=()
fi

RUN_DIR="$(mktemp -d /tmp/fg-home-photos.XXXXXX)"
EXPOSE_NAME="fg-pg-expose"
EXPOSE_CREATED=0
TUNNEL_PID=""

SSH=(ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VPS")
SCP=(scp -F /dev/null -o StrictHostKeyChecking=no -i "$SSH_KEY")

cleanup() {
  set +e
  if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
    kill "$TUNNEL_PID" 2>/dev/null || true
  fi
  if command -v ss >/dev/null 2>&1; then
    for pid in $(ss -ltnp "sport = :${LOCAL_PORT}" 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | sort -u); do
      kill "$pid" 2>/dev/null || true
    done
  fi
  if [[ "${EXPOSE_CREATED}" == "1" ]]; then
    "${SSH[@]}" "docker rm -f ${EXPOSE_NAME} >/dev/null 2>&1 || true" 2>/dev/null || true
  fi
  rm -rf "$RUN_DIR"
}
trap cleanup EXIT

umask 077
chmod 700 "$RUN_DIR"

echo "==> ensure indexer image locally"
if ! docker image inspect fitnessgirl-meet-indexer:latest >/dev/null 2>&1; then
  echo "    loading fitnessgirl-meet-indexer:latest from VPS…"
  "${SSH[@]}" "docker save fitnessgirl-meet-indexer:latest" | docker load
fi

echo "==> expose Postgres on VPS localhost:5432"
EXPOSE_OUT="$("${SSH[@]}" "bash -s" <<'REMOTE'
set -euo pipefail
EXPOSE_NAME=fg-pg-expose
if ss -ltn '( sport = :5432 )' 2>/dev/null | grep -q '127.0.0.1:5432'; then
  echo REUSE
  exit 0
fi
docker rm -f fg-pg-expose fg-pg-expose-tg >/dev/null 2>&1 || true
NET=$(docker inspect fitnessgirl-meet-db-1 --format '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' | head -1)
docker run -d --rm --name "$EXPOSE_NAME" --network "$NET" \
  -p 127.0.0.1:5432:5432 \
  alpine/socat TCP-LISTEN:5432,fork,reuseaddr TCP:fitnessgirl-meet-db-1:5432 >/dev/null
echo CREATED
REMOTE
)"
if [[ "$EXPOSE_OUT" == *CREATED* ]]; then
  EXPOSE_CREATED=1
  echo "    created ${EXPOSE_NAME}"
else
  echo "    reusing existing 127.0.0.1:5432 on VPS"
fi

echo "==> SSH tunnel 127.0.0.1:${LOCAL_PORT} -> VPS:5432"
if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
  echo "port ${LOCAL_PORT} busy; set FG_LOCAL_PORT to a free port" >&2
  exit 1
fi
ssh -f -N -L "127.0.0.1:${LOCAL_PORT}:127.0.0.1:5432" \
  -F /dev/null -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 -o ConnectTimeout=20 \
  -i "$SSH_KEY" "$VPS"
TUNNEL_PID="$(pgrep -n -f "ssh -f -N -L 127.0.0.1:${LOCAL_PORT}:127.0.0.1:5432" || true)"

echo "==> fetch secrets from VPS .env"
"${SSH[@]}" "python3 -c \"
from pathlib import Path
env={}
for line in Path('${PROJECT_DIR}/.env').read_text().splitlines():
  if not line.strip() or line.strip().startswith('#') or '=' not in line: continue
  k,v=line.split('=',1); env[k]=v.strip().strip(chr(34)).strip(chr(39))
Path('/tmp/fg-vk.token').write_text(env.get('VK_ACCESS_TOKEN',''))
Path('/tmp/fg-pg.pw').write_text(env.get('POSTGRES_PASSWORD',''))
Path('/tmp/fg-pg.user').write_text(env.get('POSTGRES_USER','fitnessgirl'))
Path('/tmp/fg-pg.db').write_text(env.get('POSTGRES_DB','fitnessgirl'))
print('token_len', len(env.get('VK_ACCESS_TOKEN','')))
\""
"${SCP[@]}" \
  "${VPS}:/tmp/fg-vk.token" "${VPS}:/tmp/fg-pg.pw" \
  "${VPS}:/tmp/fg-pg.user" "${VPS}:/tmp/fg-pg.db" \
  "$RUN_DIR/"
"${SSH[@]}" "rm -f /tmp/fg-vk.token /tmp/fg-pg.pw /tmp/fg-pg.user /tmp/fg-pg.db"
chmod 600 "$RUN_DIR"/*

PW="$(cat "$RUN_DIR/fg-pg.pw")"
PGUSER="$(cat "$RUN_DIR/fg-pg.user")"
PGDB="$(cat "$RUN_DIR/fg-pg.db")"
export VK_ACCESS_TOKEN="$(cat "$RUN_DIR/fg-vk.token")"

echo -n "==> public IP (must match VK token bind): "; curl -4 -sS --max-time 10 https://api.ipify.org; echo

echo "==> refresh photos ${CHECK_ARGS[*]:-all}"
docker run --rm --network=host \
  -e "DATABASE_URL=postgresql://${PGUSER}:${PW}@127.0.0.1:${LOCAL_PORT}/${PGDB}?schema=public" \
  -e VK_ACCESS_TOKEN \
  -e "VK_REQUEST_DELAY_MS=${VK_REQUEST_DELAY_MS:-500}" \
  -v "$ROOT/scripts/refresh-photos.ts:/app/scripts/refresh-photos.ts:ro" \
  -v "$ROOT/server/utils:/app/server/utils:ro" \
  fitnessgirl-meet-indexer:latest \
  npx tsx scripts/refresh-photos.ts "${CHECK_ARGS[@]}"

echo "==> done"
