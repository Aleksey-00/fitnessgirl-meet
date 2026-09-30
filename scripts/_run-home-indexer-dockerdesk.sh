#!/usr/bin/env bash
# Windows/WSL+Docker Desktop friendly home indexer.
# Tunnel on Windows/WSL localhost; container reaches DB via host.docker.internal.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VPS="${FG_VPS:-root@134.0.113.50}"
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
SAFE_KEY=""
# Prefer Windows path key when running under WSL
if [[ ! -f "$SSH_KEY" && -f /mnt/c/Users/aazor/.ssh/id_rsa ]]; then
  SSH_KEY=/mnt/c/Users/aazor/.ssh/id_rsa
fi
# OpenSSH rejects 0777 keys on /mnt/c — use a locked copy.
if [[ -f "$SSH_KEY" ]]; then
  SAFE_KEY="/tmp/fg_id_rsa_$$"
  cp "$SSH_KEY" "$SAFE_KEY"
  chmod 600 "$SAFE_KEY"
  SSH_KEY="$SAFE_KEY"
fi
LOCAL_PORT="${FG_LOCAL_PORT:-15432}"
DAILY_LIMIT="${FG_DAILY_LIMIT:-100}"
PROJECT_DIR="${FG_PROJECT_DIR:-/opt/fitnessgirl-meet}"
if [[ $# -eq 0 ]]; then MODE_ARGS=(--daily); else MODE_ARGS=("$@"); fi
# Ensure --daily present when only --sex=... passed
has_daily=0
has_demo=0
for a in "${MODE_ARGS[@]}"; do
  [[ "$a" == "--daily" ]] && has_daily=1
  [[ "$a" == --demo* ]] && has_demo=1
done
if [[ $has_daily -eq 0 && $has_demo -eq 0 ]]; then
  MODE_ARGS=(--daily "${MODE_ARGS[@]}")
fi

RUN_DIR="$(mktemp -d /tmp/fg-home-indexer.XXXXXX)"
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
  [[ -n "${SAFE_KEY:-}" && -f "${SAFE_KEY:-}" ]] && rm -f "$SAFE_KEY"
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
  echo REUSE; exit 0
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

echo "==> SSH tunnel 0.0.0.0:${LOCAL_PORT} -> VPS:5432 (reachable from Docker)"
if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
  echo "port ${LOCAL_PORT} busy; killing old listeners"
  for pid in $(ss -ltnp "sport = :${LOCAL_PORT}" 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | sort -u); do
    kill "$pid" 2>/dev/null || true
  done
  sleep 1
fi
ssh -f -N -L "0.0.0.0:${LOCAL_PORT}:127.0.0.1:5432" \
  -F /dev/null -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 -o ConnectTimeout=20 \
  -i "$SSH_KEY" "$VPS"
TUNNEL_PID="$(pgrep -n -f "ssh -f -N -L 0.0.0.0:${LOCAL_PORT}:127.0.0.1:5432" || true)"

echo "==> fetch secrets from VPS .env (not printed)"
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

if [[ $has_demo -eq 1 ]]; then
  echo "==> skip VK token check (demo mode, no VK calls)"
else
echo "==> VK token check"
python3 -c '
import json, pathlib, urllib.parse, urllib.request, sys, time
token=pathlib.Path("'"$RUN_DIR"'/fg-vk.token").read_text().strip()
q=urllib.parse.urlencode({"v":"5.199","access_token":token})
last=None
for attempt in range(1, 6):
  data=json.load(urllib.request.urlopen("https://api.vk.com/method/users.get?"+q, timeout=20))
  if "error" not in data:
    print("vk_ok"); sys.exit(0)
  err=data["error"]; msg=err.get("error_msg", str(err)); code=err.get("error_code"); last=msg
  if code == 9 or "Flood control" in msg:
    print(f"flood_wait attempt={attempt} {msg}")
    if attempt == 5:
      print("vk_ok_flood"); sys.exit(0)
    time.sleep(15 * attempt); continue
  print(msg); sys.exit(2)
print(last or "vk token check failed"); sys.exit(2)
'
fi

# Docker Desktop: host.docker.internal reaches the WSL/Windows host where tunnel listens.
DB_HOST="${FG_DB_HOST:-host.docker.internal}"
echo "==> start indexer ${MODE_ARGS[*]} via ${DB_HOST}:${LOCAL_PORT}"
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  -e "DATABASE_URL=postgresql://${PGUSER}:${PW}@${DB_HOST}:${LOCAL_PORT}/${PGDB}?schema=public" \
  -e VK_ACCESS_TOKEN \
  -e "VK_DAILY_LIMIT=${DAILY_LIMIT}" \
  -e "VK_REQUEST_DELAY_MS=${VK_REQUEST_DELAY_MS:-3000}" \
  -e "VK_FLOOD_COOLDOWN_MS=${VK_FLOOD_COOLDOWN_MS:-600000}" \
  -e "VK_INDEX_SEX=${VK_INDEX_SEX:-}" \
  -v "$ROOT/scripts/index-vk.ts:/app/scripts/index-vk.ts:ro" \
  -v "$ROOT/server/utils:/app/server/utils:ro" \
  fitnessgirl-meet-indexer:latest \
  npx tsx scripts/index-vk.ts "${MODE_ARGS[@]}"

echo "==> done"
