#!/usr/bin/env bash
set -euo pipefail
CLAIM_ID="${1:-cmw1wg2t5000iqo015dn8y6um}"
EMAIL_LIKE="${2:-e2e-tg-1793783604%}"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1" <<SQL
SELECT c.id, c.status, c."telegramNotifiedAt", u.email
FROM "PaymentClaim" c JOIN "User" u ON u.id = c."userId"
WHERE c.id = '${CLAIM_ID}';

SELECT s.id, s.status, s."startsAt", s."expiresAt", u.email
FROM "Subscription" s
JOIN "User" u ON u.id = s."userId"
WHERE u.email ILIKE '${EMAIL_LIKE}'
ORDER BY s."createdAt" DESC
LIMIT 5;
SQL
