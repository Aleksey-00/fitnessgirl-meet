#!/usr/bin/env bash
set -euo pipefail
EMAIL="${1:-e2e-tg-1793648837@girlmeet.com}"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<REMOTE
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<SQL
BEGIN;
SELECT id, email FROM "User" WHERE email = '${EMAIL}';
DELETE FROM "User" WHERE email = '${EMAIL}';
-- cascades to PaymentClaim + Subscription via FK
SELECT 'users' AS t, count(*)::text FROM "User"
UNION ALL SELECT 'claims', count(*)::text FROM "PaymentClaim"
UNION ALL SELECT 'subs', count(*)::text FROM "Subscription";
SELECT email FROM "User" ORDER BY email;
COMMIT;
SQL
REMOTE
