#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=25 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'echo OK; uptime; docker compose -f /opt/fitnessgirl-meet/docker-compose.yml ps'
