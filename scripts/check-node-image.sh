#!/usr/bin/env bash
set -euo pipefail
echo "node: $(command -v node || echo missing)"
node -v 2>/dev/null || true
npm -v 2>/dev/null || true
ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 \
  "docker images fitnessgirl-meet-indexer"
