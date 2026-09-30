#!/usr/bin/env bash
# Install WSL user systemd unit + linger so the Telegram bridge
# auto-starts and restarts after crashes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIT_SRC="$ROOT/scripts/fg-telegram-bridge.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_DST="$UNIT_DIR/fg-telegram-bridge.service"
LOG_DIR="$HOME/fg-logs"

echo "==> prepare logs"
mkdir -p "$LOG_DIR"
# Rotate huge spam log from old nohup runs
if [[ -f "$LOG_DIR/telegram-bridge.log" ]]; then
  size="$(wc -c <"$LOG_DIR/telegram-bridge.log" || echo 0)"
  if [[ "$size" -gt 500000 ]]; then
    mv "$LOG_DIR/telegram-bridge.log" "$LOG_DIR/telegram-bridge.log.prev"
    : >"$LOG_DIR/telegram-bridge.log"
    echo "    rotated old log (${size} bytes)"
  fi
fi

echo "==> stop legacy nohup bridge (if any)"
pkill -f '/scripts/run-home-telegram.sh' >/dev/null 2>&1 || true
sleep 1

echo "==> install user unit"
mkdir -p "$UNIT_DIR"
# Normalize CRLF from Windows checkout
sed 's/\r$//' "$UNIT_SRC" >"$UNIT_DST"
chmod 644 "$UNIT_DST"

echo "==> enable linger (optional; needs sudo once)"
if loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes'; then
  echo "    Linger=yes"
elif sudo -n loginctl enable-linger "$USER" 2>/dev/null; then
  echo "    Linger enabled (passwordless sudo)"
else
  echo "    SKIP linger (no sudo). Windows logon task will wake WSL instead."
  echo "    Optional later: sudo loginctl enable-linger $USER"
fi

echo "==> reload + enable + start"
systemctl --user daemon-reload
systemctl --user enable fg-telegram-bridge.service
systemctl --user restart fg-telegram-bridge.service
sleep 3
systemctl --user --no-pager --full status fg-telegram-bridge.service || true

echo
echo "OK: fg-telegram-bridge enabled (Restart=always, RestartSec=15)"
echo "Log: $LOG_DIR/telegram-bridge.log"
echo "Commands:"
echo "  systemctl --user status fg-telegram-bridge"
echo "  systemctl --user restart fg-telegram-bridge"
echo "  journalctl --user -u fg-telegram-bridge -f"
