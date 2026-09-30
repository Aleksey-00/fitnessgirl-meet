#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
DB=(docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1)

echo "== before delete =="
"${DB[@]}" <<'SQL'
SELECT email, role FROM "User" ORDER BY "createdAt";
SQL

echo "== delete test users (cascade subs + claims) =="
"${DB[@]}" <<'SQL'
DELETE FROM "User"
WHERE role <> 'admin'
  AND (
    lower(email) LIKE '%test%'
    OR lower(email) IN (
      'trtr@trtr.com',
      'kikotsvatik@gmail.com'
    )
  );
SQL

echo "== after delete =="
"${DB[@]}" <<'SQL'
SELECT u.id, u.email, u.role, u.gender,
       (SELECT count(*) FROM "Subscription" s WHERE s."userId"=u.id) AS subs,
       (SELECT count(*) FROM "PaymentClaim" c WHERE c."userId"=u.id) AS claims
FROM "User" u
ORDER BY u."createdAt";

SELECT s.id, u.email, s.status, s."expiresAt"
FROM "Subscription" s
JOIN "User" u ON u.id=s."userId";

SELECT c.id, u.email, c.status, c.amount
FROM "PaymentClaim" c
JOIN "User" u ON u.id=c."userId";
SQL
REMOTE
