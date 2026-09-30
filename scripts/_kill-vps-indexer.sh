#!/usr/bin/env bash
set -euo pipefail
SSH=(ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$HOME/.ssh/id_rsa" root@134.0.113.50)
echo "==> stop leftover VPS indexer runs"
"${SSH[@]}" 'cd /opt/fitnessgirl-meet; docker ps -aq --filter name=indexer-run | xargs -r docker rm -f; docker compose --profile tools ps -a || true'
echo DONE_KILL
