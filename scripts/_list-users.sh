#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT u.email, u.role, u.gender, u.\"createdAt\"::date AS created,
          EXISTS (
            SELECT 1 FROM \"Subscription\" s
            WHERE s.\"userId\"=u.id AND s.status='active' AND s.\"expiresAt\" > NOW()
          ) AS subscribed
   FROM \"User\" u
   ORDER BY u.\"createdAt\";"
REMOTE
