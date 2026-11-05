#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1' <<'SQL'
BEGIN;
CREATE TEMP TABLE _t AS
SELECT id, email FROM "User"
WHERE email ~* '(^|@)test' OR email ILIKE '%test%@%' OR email ILIKE '%e2e%';
-- Keep real accounts even if email has odd patterns
DELETE FROM _t WHERE email IN (
  'a.azorabekov1991@gmail.com',
  'a.sharapidenov@bk.ru'
) OR email NOT ILIKE '%test%' AND email NOT ILIKE '%e2e%' AND email NOT ILIKE '%girlmeet.com';
SELECT email FROM _t;
DELETE FROM "Subscription" s USING _t u WHERE s."userId"=u.id;
DELETE FROM "PaymentClaim" c USING _t u WHERE c."userId"=u.id;
DELETE FROM "User" u USING _t t WHERE u.id=t.id;
COMMIT;
SELECT u.email, c.status, c.amount FROM "PaymentClaim" c JOIN "User" u ON u.id=c."userId" ORDER BY c."createdAt" DESC;
SELECT email FROM "User" ORDER BY "createdAt" DESC;
SQL
