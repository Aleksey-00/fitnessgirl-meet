#!/usr/bin/env bash
set -euo pipefail
ROOT=/mnt/c/projects/fitnessgirl-meet
cd "$ROOT"
sed -i 's/\r$//' scripts/_run-home-indexer-dockerdesk.sh scripts/index-vk.ts
echo "[$(date -Iseconds)] seed demo males (no VK calls)"
bash scripts/_run-home-indexer-dockerdesk.sh --demo-male
echo "[$(date -Iseconds)] seed done"
