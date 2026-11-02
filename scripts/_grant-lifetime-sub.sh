#!/usr/bin/env bash
set -euo pipefail
EMAIL="${1:-a.sharapidenov@bk.ru}"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<REMOTE
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<SQL
BEGIN;
WITH u AS (
  SELECT id FROM "User" WHERE email = '${EMAIL}'
)
INSERT INTO "Subscription" (id, "userId", "startsAt", "expiresAt", status, "createdAt")
SELECT
  'c' || substr(md5(random()::text || clock_timestamp()::text), 1, 24),
  u.id,
  NOW(),
  '2099-12-31 23:59:59'::timestamp,
  'active',
  NOW()
FROM u
RETURNING id, "userId", "startsAt", "expiresAt", status;

SELECT u.email, s.status, s."startsAt", s."expiresAt"
FROM "Subscription" s
JOIN "User" u ON u.id = s."userId"
WHERE u.email = '${EMAIL}'
ORDER BY s."createdAt" DESC;
COMMIT;
SQL
REMOTE
