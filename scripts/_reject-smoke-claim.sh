#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "UPDATE \"PaymentClaim\" SET status='rejected', \"updatedAt\"=NOW() WHERE id='cm_smoke_4169707e42830bf5' AND status='pending';
   SELECT id, status, \"telegramNotifiedAt\" IS NOT NULL AS was_notified FROM \"PaymentClaim\" WHERE id='cm_smoke_4169707e42830bf5';"
REMOTE
