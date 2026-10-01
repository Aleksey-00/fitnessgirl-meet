#!/usr/bin/env bash
# Home Telegram bridge: VPS Postgres via SSH tunnel + Telegram API from this machine.
#
# Usage:
#   ./scripts/run-home-telegram.sh
#
# Optional env:
#   FG_VPS=root@134.0.113.50
#   FG_SSH_KEY=~/.ssh/id_rsa
#   FG_LOCAL_PORT=15433
#   FG_PROJECT_DIR=/opt/fitnessgirl-meet
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VPS="${FG_VPS:-root@134.0.113.50}"
SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
LOCAL_PORT="${FG_LOCAL_PORT:-15433}"
PROJECT_DIR="${FG_PROJECT_DIR:-/opt/fitnessgirl-meet}"
RUN_DIR="$(mktemp -d /tmp/fg-home-tg.XXXXXX)"
# Shared with run-home-indexer.sh — only one VPS :5432 publish.
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
  pkill -f "ssh -f -N -L .*:${LOCAL_PORT}:127.0.0.1:5432" 2>/dev/null || true
  # Keep shared expose up for the other home script / service.
  if [[ "${EXPOSE_CREATED}" == "1" ]]; then
    "${SSH[@]}" "docker rm -f ${EXPOSE_NAME} >/dev/null 2>&1 || true" 2>/dev/null || true
  fi
  rm -rf "$RUN_DIR"
}
trap cleanup EXIT

umask 077
chmod 700 "$RUN_DIR"

echo "==> ensure tools image locally"
if ! docker image inspect fitnessgirl-meet-indexer:latest >/dev/null 2>&1; then
  echo "    loading fitnessgirl-meet-indexer:latest from VPS…"
  "${SSH[@]}" "docker save fitnessgirl-meet-indexer:latest" | docker load
fi

echo "==> expose Postgres on VPS 127.0.0.1:5432"
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

# Docker Desktop's --network=host does NOT share WSL loopback. Bind the tunnel
# on the WSL eth IP and reach it from a normal bridge-network container.
WSL_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${WSL_IP}" ]]; then
  echo "cannot detect WSL IP for DB tunnel" >&2
  exit 1
fi

echo "==> SSH tunnel ${WSL_IP}:${LOCAL_PORT} -> VPS:5432"
if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
  echo "port ${LOCAL_PORT} busy; set FG_LOCAL_PORT to a free port" >&2
  exit 1
fi
ssh -f -N -L "${WSL_IP}:${LOCAL_PORT}:127.0.0.1:5432" \
  -F /dev/null -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=4 -o ConnectTimeout=20 \
  -i "$SSH_KEY" "$VPS"
TUNNEL_PID="$(pgrep -n -f "ssh -f -N -L ${WSL_IP}:${LOCAL_PORT}:127.0.0.1:5432" || true)"
for i in $(seq 1 40); do
  if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
    echo "    tunnel ready (pid=${TUNNEL_PID:-?})"
    break
  fi
  if [[ "$i" -eq 40 ]]; then
    echo "SSH tunnel did not open on :${LOCAL_PORT}" >&2
    exit 1
  fi
  sleep 0.25
done

echo "==> fetch secrets from VPS .env"
"${SSH[@]}" "python3 - <<'PY'
from pathlib import Path
env={}
for line in Path('${PROJECT_DIR}/.env').read_text().splitlines():
  if not line.strip() or line.strip().startswith('#') or '=' not in line: continue
  k,v=line.split('=',1); env[k]=v.strip().strip(chr(34)).strip(chr(39))
Path('/tmp/fg-tg.token').write_text(env.get('TELEGRAM_BOT_TOKEN',''))
Path('/tmp/fg-tg.chat').write_text(env.get('TELEGRAM_ADMIN_CHAT_ID',''))
Path('/tmp/fg-pg.pw').write_text(env.get('POSTGRES_PASSWORD',''))
Path('/tmp/fg-pg.user').write_text(env.get('POSTGRES_USER') or 'fitnessgirl')
Path('/tmp/fg-pg.db').write_text(env.get('POSTGRES_DB') or 'fitnessgirl')
Path('/tmp/fg-sub.days').write_text(env.get('SUBSCRIPTION_DAYS') or '30')
print('tg_token_len', len(env.get('TELEGRAM_BOT_TOKEN','')))
PY"
"${SCP[@]}" \
  "${VPS}:/tmp/fg-tg.token" "${VPS}:/tmp/fg-tg.chat" \
  "${VPS}:/tmp/fg-pg.pw" "${VPS}:/tmp/fg-pg.user" "${VPS}:/tmp/fg-pg.db" \
  "${VPS}:/tmp/fg-sub.days" \
  "$RUN_DIR/"
"${SSH[@]}" "rm -f /tmp/fg-tg.token /tmp/fg-tg.chat /tmp/fg-pg.pw /tmp/fg-pg.user /tmp/fg-pg.db /tmp/fg-sub.days"
chmod 600 "$RUN_DIR"/*

PW="$(cat "$RUN_DIR/fg-pg.pw")"
PGUSER="$(cat "$RUN_DIR/fg-pg.user")"
PGDB="$(cat "$RUN_DIR/fg-pg.db")"
export TELEGRAM_BOT_TOKEN="$(cat "$RUN_DIR/fg-tg.token")"
export TELEGRAM_ADMIN_CHAT_ID="$(cat "$RUN_DIR/fg-tg.chat")"
export SUBSCRIPTION_DAYS="$(cat "$RUN_DIR/fg-sub.days")"
export DATABASE_URL="postgresql://${PGUSER}:${PW}@${WSL_IP}:${LOCAL_PORT}/${PGDB}?schema=public"

echo -n "==> public IP: "; curl -4 -sS --max-time 10 https://api.ipify.org; echo
echo "==> Telegram getMe"
python3 -c '
import json, pathlib, urllib.request, sys
token=pathlib.Path("'"$RUN_DIR"'/fg-tg.token").read_text().strip()
data=json.load(urllib.request.urlopen("https://api.telegram.org/bot"+token+"/getMe", timeout=20))
print("bot_ok" if data.get("ok") else data)
if not data.get("ok"):
  sys.exit(2)
'

echo "==> probe DB via docker bridge -> ${WSL_IP}:${LOCAL_PORT}"
if ! docker run --rm busybox:1.36 nc -zvw5 "${WSL_IP}" "${LOCAL_PORT}" >/dev/null 2>&1; then
  echo "docker cannot reach tunnel at ${WSL_IP}:${LOCAL_PORT}" >&2
  exit 1
fi

echo "==> start telegram-poll (Ctrl+C to stop)"
# No --network=host: Docker Desktop host-net cannot see WSL loopback/SSH tunnels.
docker run --rm \
  -v "$ROOT/scripts:/app/scripts:ro" \
  -e DATABASE_URL \
  -e TELEGRAM_BOT_TOKEN \
  -e TELEGRAM_ADMIN_CHAT_ID \
  -e SUBSCRIPTION_DAYS \
  fitnessgirl-meet-indexer:latest \
  npx tsx scripts/telegram-poll.ts
