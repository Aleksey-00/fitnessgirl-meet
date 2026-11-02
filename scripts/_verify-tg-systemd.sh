#!/usr/bin/env bash
set -euo pipefail
sleep 20
echo '=== systemd ==='
systemctl --user is-active fg-telegram-bridge.service
systemctl --user --no-pager status fg-telegram-bridge.service | sed -n '1,18p'
echo '=== log ==='
tail -n 15 "$HOME/fg-logs/telegram-bridge.log"
echo '=== docker ==='
docker ps --format '{{.Names}} {{.Status}} {{.Image}}'
echo '=== pollers ==='
pgrep -af 'run-home-telegram|telegram-poll' || true
