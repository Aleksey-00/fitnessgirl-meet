#!/usr/bin/env bash
set -euo pipefail
pkill -f 'run-home-indexer.sh' 2>/dev/null || true
pkill -f 'index-vk.ts' 2>/dev/null || true
# kill docker run of indexer if any
docker ps --format '{{.ID}} {{.Image}} {{.Command}}' | while read -r id img cmd; do
  case "$img $cmd" in
    *fitnessgirl-meet-indexer*|*index-vk*) docker rm -f "$id" 2>/dev/null || true ;;
  esac
done
pgrep -af 'index-vk|run-home-indexer' || echo 'no indexer procs'
echo STOPPED
