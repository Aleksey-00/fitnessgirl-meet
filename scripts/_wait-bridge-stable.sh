#!/usr/bin/env bash
set -euo pipefail
echo "==> wait poller running + heartbeat"
for i in $(seq 1 40); do
  st="$(docker inspect -f '{{.State.Status}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r' || true)"
  if [[ "$st" == "running" ]] && docker logs fg-home-telegram-poll 2>&1 | grep -q 'heartbeat loops='; then
    echo "STABLE status=$st"
    docker logs fg-home-telegram-poll --tail 15 2>&1
    pgrep -af 'run-home-telegram' || true
    systemctl --user is-active fg-telegram-bridge.service
    exit 0
  fi
  echo "wait $i status=${st:-none}"
  sleep 2
done
echo "NOT STABLE" >&2
docker logs fg-home-telegram-poll --tail 40 2>&1 || true
systemctl --user --no-pager status fg-telegram-bridge.service | sed -n '1,30p' || true
exit 1
