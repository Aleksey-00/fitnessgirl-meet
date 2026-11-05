#!/usr/bin/env bash
# Remove E2E / test payment claims (+ their users/subs) from prod. Keeps real accounts.
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1' <<'SQL'
BEGIN;

CREATE TEMP TABLE _test_users AS
SELECT id, email FROM "User"
WHERE email ~* '^(e2e-|girltest@|test@test\.com$)'
   OR email ILIKE '%@girlmeet.com';

SELECT email AS will_delete_user FROM _test_users ORDER BY email;

DELETE FROM "Subscription" s
USING _test_users u
WHERE s."userId" = u.id;

DELETE FROM "PaymentClaim" c
USING _test_users u
WHERE c."userId" = u.id;

-- Also drop orphan test claims by note/provider if any leftover emails slipped
DELETE FROM "PaymentClaim" c
WHERE c.note ILIKE '%e2e%'
   OR c.note ILIKE '%telegram approve test%';

DELETE FROM "User" u
USING _test_users t
WHERE u.id = t.id;

COMMIT;

SELECT 'remaining_claims' AS k, count(*)::text AS v FROM "PaymentClaim"
UNION ALL
SELECT 'remaining_users', count(*)::text FROM "User";

SELECT c.id, c.status, c.amount, u.email
FROM "PaymentClaim" c JOIN "User" u ON u.id = c."userId"
ORDER BY c."createdAt" DESC LIMIT 20;
SQL
