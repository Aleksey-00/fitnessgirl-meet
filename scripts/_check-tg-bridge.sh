#!/usr/bin/env bash
set -euo pipefail
echo '== local telegram container logs'
docker ps --format '{{.Names}} {{.Status}} {{.Image}}' | head -20
CID="$(docker ps -q --filter ancestor=fitnessgirl-meet-indexer:latest | head -1 || true)"
if [[ -n "${CID:-}" ]]; then
  docker logs "$CID" --tail 50 2>&1 || true
else
  echo 'no indexer-based telegram container'
  docker logs admiring_gates --tail 50 2>&1 || true
fi
echo '== local 15432'
ss -ltn 2>/dev/null | grep 15432 || echo 'no local 15432 listener'
echo '== vps 5432 / expose'
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 \
  "ss -ltn | grep 5432 || true; docker ps -a --format '{{.Names}} {{.Status}}' | grep fg-pg || true"
