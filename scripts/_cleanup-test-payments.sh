#!/usr/bin/env bash
# Delete test users + their claims/subscriptions on prod.
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<'SQL'
BEGIN;
-- Test accounts only (keep real customers / admin).
DELETE FROM "User"
WHERE email IN (
  'test@girlmeet.com',
  'test222test@mail.com',
  'test@test1991.ru',
  'test@test.com'
)
OR email LIKE 'e2e-tg-%@girlmeet.com';

-- Orphan smoke claims if any
DELETE FROM "PaymentClaim" WHERE id LIKE 'cm_smoke_%';

SELECT 'users_left' AS k, count(*)::text AS v FROM "User"
UNION ALL
SELECT 'claims_left', count(*)::text FROM "PaymentClaim"
UNION ALL
SELECT 'subs_left', count(*)::text FROM "Subscription";

SELECT email FROM "User" ORDER BY "createdAt";
SELECT u.email, c.status, c.provider
FROM "PaymentClaim" c JOIN "User" u ON u.id=c."userId"
ORDER BY c."createdAt" DESC LIMIT 20;
COMMIT;
SQL
REMOTE
