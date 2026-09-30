#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1 <<'SQL'
DELETE FROM "User" WHERE lower(email) = lower('qa-female-tmp@fitnessgirl.local');
SELECT email, role FROM "User" ORDER BY "createdAt";
SELECT count(*) AS claims FROM "PaymentClaim";
SELECT count(*) AS subs FROM "Subscription";
SQL
REMOTE
