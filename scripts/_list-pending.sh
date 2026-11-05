#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "
SELECT c.id, c.status, c.amount, c.\"telegramNotifiedAt\", c.\"createdAt\", u.email
FROM \"PaymentClaim\" c JOIN \"User\" u ON u.id = c.\"userId\"
ORDER BY c.\"createdAt\" DESC LIMIT 15;
SELECT s.id, s.status, s.\"expiresAt\", u.email
FROM \"Subscription\" s JOIN \"User\" u ON u.id = s.\"userId\"
WHERE s.status = '"'"'active'"'"'
ORDER BY s.\"createdAt\" DESC LIMIT 10;
"'
