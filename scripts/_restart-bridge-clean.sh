#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
sed -i 's/\r$//' "$ROOT/scripts/run-home-telegram.sh" "$ROOT/scripts/fg-telegram-bridge.service" "$ROOT/scripts/telegram-poll.ts" || true
sed 's/\r$//' "$ROOT/scripts/fg-telegram-bridge.service" >"$HOME/.config/systemd/user/fg-telegram-bridge.service"
systemctl --user daemon-reload
systemctl --user restart fg-telegram-bridge.service
echo "waiting for stable poller…"
for i in $(seq 1 40); do
  st="$(docker inspect -f '{{.State.Status}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r' || true)"
  if [[ "$st" == "running" ]] && docker logs fg-home-telegram-poll 2>&1 | grep -q 'heartbeat loops='; then
    n="$(pgrep -f '/scripts/run-home-telegram.sh' | wc -l | tr -d ' ')"
    echo "OK poller=$st bridge_procs=$n"
    docker logs fg-home-telegram-poll --tail 8 2>&1
    [[ "$n" -eq 1 ]] || echo "WARN: expected 1 bridge process, got $n" >&2
    systemctl --user is-active fg-telegram-bridge.service
    exit 0
  fi
  sleep 2
done
systemctl --user --no-pager status fg-telegram-bridge.service | sed -n '1,25p' || true
docker logs fg-home-telegram-poll --tail 40 2>&1 || true
exit 1
