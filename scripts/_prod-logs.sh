#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo '== app logs =='
docker compose logs --tail=120 app
echo '== ps =='
docker compose ps
REMOTE
