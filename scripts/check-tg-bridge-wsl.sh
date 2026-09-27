#!/usr/bin/env bash
set -euo pipefail
echo "=== procs ==="
ps -ef | grep -E 'run-home-telegram|docker save|docker load|telegram-poll|ssh -f -N' | grep -v grep || echo none
echo "=== images ==="
docker images
echo "=== image inspect ==="
if docker image inspect fitnessgirl-meet-indexer:latest >/dev/null 2>&1; then
  echo IMAGE_OK
else
  echo IMAGE_MISSING
fi
echo "=== log ==="
tail -n 80 /home/aazor/fg-logs/telegram-bridge.log || true
echo "=== children of bridge ==="
pgrep -P 907 -a || true
ps --ppid 907 -o pid,cmd || true
