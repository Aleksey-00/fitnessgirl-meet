#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "
SELECT u.email, u.role, u.gender, u.\"createdAt\",
  (SELECT count(*) FROM \"PaymentClaim\" c WHERE c.\"userId\"=u.id) AS claims,
  (SELECT count(*) FROM \"Subscription\" s WHERE s.\"userId\"=u.id AND s.status='"'"'active'"'"' AND s.\"expiresAt\">NOW()) AS active_subs
FROM \"User\" u
ORDER BY u.\"createdAt\" ASC;
"'
