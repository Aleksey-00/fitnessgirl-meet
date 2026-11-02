#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<'SQL'
SELECT c.id, c.status, c.provider, u.email, c."telegramNotifiedAt",
       (SELECT count(*) FROM "Subscription" s WHERE s."userId"=c."userId") AS subs
FROM "PaymentClaim" c
JOIN "User" u ON u.id=c."userId"
WHERE u.email IN ('test@girlmeet.com','test222test@mail.com')
   OR u.email ILIKE '%test%'
ORDER BY c."createdAt" DESC;
SELECT s.id, u.email, s.status, s."startsAt", s."expiresAt"
FROM "Subscription" s JOIN "User" u ON u.id=s."userId"
ORDER BY s."createdAt" DESC LIMIT 20;
SQL
REMOTE
echo '=== live bridge log ==='
tail -n 30 "$HOME/fg-logs/telegram-bridge.log"
