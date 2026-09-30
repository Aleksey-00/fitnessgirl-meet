#!/usr/bin/env bash
# Start / restart home Telegram bridge (prefers systemd user unit).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
sed -i 's/\r$//' scripts/run-home-telegram.sh scripts/fg-telegram-bridge.service 2>/dev/null || true

export FG_SSH_KEY="${FG_SSH_KEY:-$HOME/.ssh/id_rsa}"
export FG_VPS="${FG_VPS:-root@134.0.113.50}"
mkdir -p "$HOME/fg-logs"
LOG="$HOME/fg-logs/telegram-bridge.log"

if systemctl --user status fg-telegram-bridge.service >/dev/null 2>&1 \
  || systemctl --user cat fg-telegram-bridge.service >/dev/null 2>&1; then
  echo "==> systemd user unit"
  systemctl --user restart fg-telegram-bridge.service
  sleep 3
  systemctl --user --no-pager --full status fg-telegram-bridge.service || true
  echo "LOG=$LOG"
  exit 0
fi

echo "==> fallback nohup (unit not installed; run scripts/install-tg-bridge-autostart.sh)"
pkill -f '/scripts/run-home-telegram.sh' >/dev/null 2>&1 || true
sleep 1
nohup bash ./scripts/run-home-telegram.sh >"$LOG" 2>&1 &
PID=$!
echo "STARTED_PID=$PID"
echo "LOG=$LOG"
sleep 4
echo "=== log ==="
tail -n 50 "$LOG" || true
