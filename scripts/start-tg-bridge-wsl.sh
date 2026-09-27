#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
sed -i 's/\r$//' scripts/run-home-telegram.sh || true

export FG_SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
export FG_VPS="${FG_VPS:-root@134.0.113.50}"

mkdir -p "$HOME/fg-logs"
LOG="$HOME/fg-logs/telegram-bridge.log"

# Stop previous bridge instances
pkill -f '/scripts/run-home-telegram.sh' >/dev/null 2>&1 || true
sleep 1

nohup bash ./scripts/run-home-telegram.sh >"$LOG" 2>&1 &
PID=$!
echo "STARTED_PID=$PID"
echo "LOG=$LOG"
sleep 4
echo "=== log ==="
tail -n 50 "$LOG" || true
