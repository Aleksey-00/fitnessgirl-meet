#!/bin/sh
set -e
echo "[$(date -Iseconds)] daily indexer loop started"
# Small initial delay so DB is ready after compose up
sleep 5
while true; do
  echo "[$(date -Iseconds)] running daily index (+~100 profiles)"
  npx tsx scripts/index-vk.ts --daily || echo "[$(date -Iseconds)] daily index failed (will retry tomorrow)"
  echo "[$(date -Iseconds)] sleeping 24h"
  sleep 86400
done
