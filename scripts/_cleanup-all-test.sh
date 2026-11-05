#!/usr/bin/env bash
# Delete ALL test claims/users/subs on prod. Keep real accounts. No service restarts.
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1' <<'SQL'
BEGIN;

CREATE TEMP TABLE _keep AS
SELECT id FROM "User" WHERE email IN (
  'a.azorabekov1991@gmail.com',
  'a.sharapidenov@bk.ru',
  'timofeibogdashkin@gmail.com',
  'amfjtue@mail.ru'
);

CREATE TEMP TABLE _test AS
SELECT u.id, u.email
FROM "User" u
WHERE u.id NOT IN (SELECT id FROM _keep)
  AND (
    u.email ILIKE '%test%'
    OR u.email ILIKE '%e2e%'
    OR u.email ILIKE '%girlmeet.com'
    OR u.email ILIKE 'browser-%'
    OR u.email ~* '^(e2e|girltest|browser)'
  );

SELECT 'BEFORE_DELETE' AS phase, email FROM _test ORDER BY email;
SELECT 'BEFORE_CLAIMS' AS phase, c.id, c.status, u.email, c.note
FROM "PaymentClaim" c JOIN "User" u ON u.id=c."userId"
WHERE u.id IN (SELECT id FROM _test)
   OR c.note ILIKE '%e2e%'
   OR c.note ILIKE '%browser%'
   OR c.note ILIKE '%telegram approve%'
ORDER BY c."createdAt" DESC;

DELETE FROM "Subscription" s WHERE s."userId" IN (SELECT id FROM _test);
DELETE FROM "PaymentClaim" c WHERE c."userId" IN (SELECT id FROM _test);
DELETE FROM "PaymentClaim" c
WHERE c.note ILIKE '%e2e%'
   OR c.note ILIKE '%browser%'
   OR c.note ILIKE '%telegram approve%';
DELETE FROM "User" u WHERE u.id IN (SELECT id FROM _test);

COMMIT;

SELECT 'AFTER_USERS' AS k, email AS v FROM "User" ORDER BY email;
SELECT 'AFTER_CLAIMS' AS k, u.email||' / '||c.status||' / '||c.amount::text AS v
FROM "PaymentClaim" c JOIN "User" u ON u.id=c."userId"
ORDER BY c."createdAt" DESC;
SQL
