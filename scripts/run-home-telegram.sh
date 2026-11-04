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

# Prefer the git checkout even if this file was copied to /tmp for CRLF normalization.
ROOT="${FG_PROJECT_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [[ -d "$SCRIPT_DIR/../scripts" && -f "$SCRIPT_DIR/../package.json" ]]; then
    ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  else
    ROOT="/mnt/c/projects/fitnessgirl-meet"
  fi
fi
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
POLL_NAME="fg-home-telegram-poll"
# Fixed path (not XDG_RUNTIME_DIR): systemd + interactive shells must share one lock.
# Overlapping bridges docker-rm each other's poller and drop TG approve clicks.
LOCK_FILE="/tmp/fg-telegram-bridge.lock"
PID_FILE="/tmp/fg-telegram-bridge.pid"
OWN_POLLER=0

# Only one bridge instance — overlapping starts SIGTERM the poller and drop TG clicks.
# Wait for the old holder (systemd stop) instead of exit 0, which would leave no bridge.
exec 9>"$LOCK_FILE"
echo "==> waiting for bridge lock ($LOCK_FILE)"
if ! flock -w 120 9; then
  echo "could not acquire bridge lock within 120s; exiting for systemd retry" >&2
  exit 1
fi
echo "==> lock acquired (pid=$$)"
echo $$ >"$PID_FILE"

SSH=(ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -i "$SSH_KEY" "$VPS")

cleanup() {
  set +e
  # Only tear down resources we still own. Never pkill foreign tunnels — that races a
  # replacement bridge and makes systemd flap (tunnel die → exit → restart → SIGTERM poller).
  if [[ -f "$PID_FILE" ]] && [[ "$(cat "$PID_FILE" 2>/dev/null || true)" == "$$" ]]; then
    if [[ "$OWN_POLLER" == "1" ]]; then
      # Graceful stop first so an in-flight approve can finish before SIGKILL.
      docker stop -t 15 "$POLL_NAME" >/dev/null 2>&1 || true
      docker rm -f "$POLL_NAME" >/dev/null 2>&1 || true
    fi
    if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
      kill "$TUNNEL_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
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
WSL_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
if [[ -z "${WSL_IP}" ]]; then
  WSL_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
# Prefer non-docker0 address if hostname -I put 172.17.0.1 first.
if [[ "${WSL_IP}" == "172.17.0.1" ]]; then
  WSL_IP="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^172\.17\.' | head -1 || true)"
fi
if [[ -z "${WSL_IP}" ]]; then
  echo "cannot detect WSL IP for DB tunnel" >&2
  exit 1
fi

echo "==> SSH tunnel ${WSL_IP}:${LOCAL_PORT} -> VPS:5432"
# Drop a stale forward left by a previous crash.
if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
  echo "    clearing stale listener on :${LOCAL_PORT}"
  for pid in $(ss -ltnp "sport = :${LOCAL_PORT}" 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | sort -u); do
    kill "$pid" 2>/dev/null || true
  done
  pkill -f "ssh -f -N -L .*:${LOCAL_PORT}:127.0.0.1:5432" 2>/dev/null || true
  sleep 1
fi
# Foreground ssh in background — $! is reliable (ssh -f + pgrep often tracks the wrong pid
# and the watcher then exits → systemd restart → SIGTERM mid-notify).
ssh -N -L "${WSL_IP}:${LOCAL_PORT}:127.0.0.1:5432" \
  -F /dev/null -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=4 -o ConnectTimeout=20 \
  -i "$SSH_KEY" "$VPS" &
TUNNEL_PID=$!
for i in $(seq 1 40); do
  if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
    echo "    tunnel ready (pid=${TUNNEL_PID})"
    break
  fi
  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    echo "SSH tunnel process exited before listen" >&2
    exit 1
  fi
  if [[ "$i" -eq 40 ]]; then
    echo "SSH tunnel did not open on :${LOCAL_PORT}" >&2
    exit 1
  fi
  sleep 0.25
done

echo "==> fetch secrets from VPS .env"
# One SSH session: write files, stream tar on stdout (scp/sftp hangs behind Clash).
"${SSH[@]}" "python3 - <<'PY'
from pathlib import Path
import sys
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
print('tg_token_len', len(env.get('TELEGRAM_BOT_TOKEN','')), file=sys.stderr)
PY
tar -C /tmp -cf - fg-tg.token fg-tg.chat fg-pg.pw fg-pg.user fg-pg.db fg-sub.days
rm -f /tmp/fg-tg.token /tmp/fg-tg.chat /tmp/fg-pg.pw /tmp/fg-pg.user /tmp/fg-pg.db /tmp/fg-sub.days
" | tar -C "$RUN_DIR" -xf -
chmod 600 "$RUN_DIR"/*

PW="$(cat "$RUN_DIR/fg-pg.pw")"
PGUSER="$(cat "$RUN_DIR/fg-pg.user")"
PGDB="$(cat "$RUN_DIR/fg-pg.db")"
export TELEGRAM_BOT_TOKEN="$(cat "$RUN_DIR/fg-tg.token")"
export TELEGRAM_ADMIN_CHAT_ID="$(cat "$RUN_DIR/fg-tg.chat")"
export SUBSCRIPTION_DAYS="$(cat "$RUN_DIR/fg-sub.days")"
PW_ENC="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$PW")"
export DATABASE_URL="postgresql://${PGUSER}:${PW_ENC}@${WSL_IP}:${LOCAL_PORT}/${PGDB}?schema=public"

echo -n "==> public IP: "; curl -4 -sS --max-time 10 https://api.ipify.org || echo "(ipify timeout)"; echo
echo "==> Telegram getMe"
python3 -c '
import json, pathlib, urllib.request, urllib.error, sys, time
token=pathlib.Path("'"$RUN_DIR"'/fg-tg.token").read_text().strip()
last=None
for i in range(1, 6):
  try:
    data=json.load(urllib.request.urlopen("https://api.telegram.org/bot"+token+"/getMe", timeout=20))
    print("bot_ok" if data.get("ok") else data)
    if data.get("ok"):
      sys.exit(0)
    last=data
  except Exception as e:
    last=e
    print("getMe retry", i, e)
    time.sleep(3)
print("getMe failed:", last)
sys.exit(2)
'

echo "==> probe DB via docker bridge -> ${WSL_IP}:${LOCAL_PORT}"
if ! docker run --rm busybox:1.36 nc -zvw5 "${WSL_IP}" "${LOCAL_PORT}" >/dev/null 2>&1; then
  echo "docker cannot reach tunnel at ${WSL_IP}:${LOCAL_PORT}" >&2
  exit 1
fi

start_poll_container() {
  echo "==> start telegram-poll container (${POLL_NAME})"
  # No --network=host: Docker Desktop host-net cannot see WSL loopback/SSH tunnels.
  # Stop gracefully before rm -f so mid-approve work can commit.
  docker stop -t 15 "$POLL_NAME" >/dev/null 2>&1 || true
  docker rm -f "$POLL_NAME" >/dev/null 2>&1 || true
  # No --restart: this watcher recreates the poller in-place without tearing the tunnel.
  docker run -d --name "$POLL_NAME" \
    --label fg.bridge.pid="$$" \
    -v "$ROOT/scripts:/app/scripts:ro" \
    -e DATABASE_URL \
    -e TELEGRAM_BOT_TOKEN \
    -e TELEGRAM_ADMIN_CHAT_ID \
    -e SUBSCRIPTION_DAYS \
    fitnessgirl-meet-indexer:latest \
    npx tsx scripts/telegram-poll.ts >/dev/null
  OWN_POLLER=1
}

poll_running() {
  # Docker Desktop on Windows may append CR to format output — trim it.
  local st
  st="$(docker inspect -f '{{.State.Status}}' "$POLL_NAME" 2>/dev/null | tr -d '\r' || true)"
  [[ "$st" == "running" ]]
}

start_poll_container

# Keep tunnel up; recreate poller if it dies. Only exit (systemd full restart)
# when the SSH tunnel itself is dead.
tunnel_ok() {
  # Prefer port listen over pid: ssh may double-fork; pid alone false-negatives.
  if ss -ltn "sport = :${LOCAL_PORT}" 2>/dev/null | grep -q LISTEN; then
    return 0
  fi
  if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
    return 0
  fi
  return 1
}

echo "==> watching ${POLL_NAME} (tunnel pid=${TUNNEL_PID:-?})"
misses=0
poll_restarts=0
while true; do
  if ! tunnel_ok; then
    echo "SSH tunnel died (no listener on :${LOCAL_PORT}); exiting for systemd restart" >&2
    if [[ "$OWN_POLLER" == "1" ]]; then
      docker stop -t 10 "$POLL_NAME" >/dev/null 2>&1 || true
      docker rm -f "$POLL_NAME" >/dev/null 2>&1 || true
    fi
    exit 1
  fi
  if poll_running; then
    misses=0
  else
    misses=$((misses + 1))
    if [[ "$misses" -ge 2 ]]; then
      poll_restarts=$((poll_restarts + 1))
      echo "poller not running (misses=${misses}); restart #${poll_restarts}" >&2
      docker logs "$POLL_NAME" 2>&1 | tail -n 40 || true
      if [[ "$poll_restarts" -ge 20 ]]; then
        echo "too many poller restarts; exiting for systemd/tunnel rebuild" >&2
        exit 1
      fi
      # Re-probe DB before recreating — tunnel IP can go stale after Docker Desktop blips.
      if ! docker run --rm busybox:1.36 nc -zvw5 "${WSL_IP}" "${LOCAL_PORT}" >/dev/null 2>&1; then
        echo "docker lost tunnel at ${WSL_IP}:${LOCAL_PORT}; exiting" >&2
        exit 1
      fi
      start_poll_container
      misses=0
    fi
  fi
  sleep 5
done
