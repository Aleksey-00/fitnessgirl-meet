#!/usr/bin/env bash
set -euo pipefail
LOG=/home/aazor/fg-logs/telegram-bridge.log
for n in $(seq 1 40); do
  if docker image inspect fitnessgirl-meet-indexer:latest >/dev/null 2>&1; then
    echo "IMAGE_READY at step $n"
    break
  fi
  if ! pgrep -f 'docker load' >/dev/null 2>&1; then
    echo "docker load ended without image at step $n"
    break
  fi
  echo "waiting step $n"
  sleep 30
done
echo "=== log ==="
tail -n 100 "$LOG" || true
echo "=== procs ==="
ps -ef | grep -E 'run-home-telegram|telegram-poll|docker load|docker save' | grep -v grep || true
docker images
