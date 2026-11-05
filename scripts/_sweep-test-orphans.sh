#!/usr/bin/env bash
# Extra sweep: any leftover test-ish claims/subs/users.
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1' <<'SQL'
SELECT 'users' AS t, email AS v FROM "User" ORDER BY email;
SELECT 'claims' AS t, u.email||' '||c.status||' '||coalesce(c.note,'') AS v
FROM "PaymentClaim" c JOIN "User" u ON u.id=c."userId" ORDER BY c."createdAt" DESC;
SELECT 'subs' AS t, u.email||' '||s.status AS v
FROM "Subscription" s JOIN "User" u ON u.id=s."userId" ORDER BY s."createdAt" DESC;
SELECT 'orphan_claims' AS t, c.id AS v FROM "PaymentClaim" c
LEFT JOIN "User" u ON u.id=c."userId" WHERE u.id IS NULL;
SELECT 'orphan_subs' AS t, s.id AS v FROM "Subscription" s
LEFT JOIN "User" u ON u.id=s."userId" WHERE u.id IS NULL;
SQL
