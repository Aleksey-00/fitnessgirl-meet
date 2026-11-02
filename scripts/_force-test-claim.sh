#!/usr/bin/env bash
# Create a pending manual claim for test222test@mail.com if none pending,
# so home telegram-poll can notify. Does not approve.
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<'SQL'
DO $$
DECLARE
  uid text;
  pending_id text;
BEGIN
  SELECT id INTO uid FROM "User" WHERE email = 'test222test@mail.com';
  IF uid IS NULL THEN
    RAISE EXCEPTION 'user not found';
  END IF;
  SELECT id INTO pending_id FROM "PaymentClaim" WHERE "userId" = uid AND status = 'pending' LIMIT 1;
  IF pending_id IS NOT NULL THEN
    RAISE NOTICE 'already pending %', pending_id;
  ELSE
    INSERT INTO "PaymentClaim" (id, "userId", amount, note, status, provider, "createdAt", "updatedAt")
    VALUES (
      'cm_smoke_' || substr(md5(random()::text), 1, 16),
      uid,
      450,
      'smoke after deploy',
      'pending',
      'manual',
      NOW(),
      NOW()
    );
    RAISE NOTICE 'created pending claim';
  END IF;
END $$;
SELECT c.id, c.status, c.provider, c."telegramNotifiedAt", c.note
FROM "PaymentClaim" c
JOIN "User" u ON u.id = c."userId"
WHERE u.email = 'test222test@mail.com'
ORDER BY c."createdAt" DESC
LIMIT 3;
SQL
REMOTE
