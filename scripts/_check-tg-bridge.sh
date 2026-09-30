#!/usr/bin/env bash
set -euo pipefail
sleep 10
echo "== status =="
systemctl --user --no-pager --full status fg-telegram-bridge.service | head -30
echo "== log =="
tail -n 50 "$HOME/fg-logs/telegram-bridge.log" || true
echo "== procs =="
pgrep -af 'telegram-poll|run-home-telegram' || true
