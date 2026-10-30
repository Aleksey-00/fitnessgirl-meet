#!/bin/sh
set -e
echo "[$(date -Iseconds)] daily indexer loop started"
# Small initial delay so DB is ready after compose up
sleep 5
while true; do
  echo "[$(date -Iseconds)] running daily index (+~100 profiles)"
  npx tsx scripts/index-vk.ts --daily || echo "[$(date -Iseconds)] daily index failed (will retry tomorrow)"
  # VK CDN hotlinks expire; refresh dead avatars so /catalog stays intact.
  echo "[$(date -Iseconds)] refreshing dead VK photo URLs"
  npx tsx scripts/refresh-photos.ts --check || echo "[$(date -Iseconds)] photo refresh failed (non-fatal)"
  echo "[$(date -Iseconds)] sleeping 24h"
  sleep 86400
done
