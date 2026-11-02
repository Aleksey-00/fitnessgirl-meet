#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo '== user + claims'
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<'SQL'
SELECT u.id, u.email FROM "User" u WHERE u.email='test@girlmeet.com';
SELECT c.id, c.status, c.provider, c.amount, c.note,
       c."telegramNotifiedAt", c."createdAt"
FROM "PaymentClaim" c
JOIN "User" u ON u.id=c."userId"
WHERE u.email='test@girlmeet.com'
ORDER BY c."createdAt" DESC;
SELECT id, status, provider, "telegramNotifiedAt", "createdAt"
FROM "PaymentClaim"
WHERE status='pending' AND "telegramNotifiedAt" IS NULL
ORDER BY "createdAt" DESC LIMIT 10;
SQL
echo '== app logs'
docker logs fitnessgirl-meet-app-1 --since 45m 2>&1 | grep -iE 'claim|Telegram|girlmeet|PaymentClaim|Prisma' | tail -40 || true
REMOTE
