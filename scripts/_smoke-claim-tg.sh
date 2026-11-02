#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
echo '== payments info'
curl -fsS http://127.0.0.1:3000/api/payments/info; echo
echo '== prisma client invId'
docker exec fitnessgirl-meet-app-1 grep invId /app/node_modules/.prisma/client/schema.prisma | sed -n '1,2p'
echo '== test user claims'
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT u.email, c.id, c.status, c.provider, c.\"telegramNotifiedAt\" IS NOT NULL AS tg_notified, c.\"createdAt\"
   FROM \"PaymentClaim\" c JOIN \"User\" u ON u.id=c.\"userId\"
   WHERE u.email='test222test@mail.com'
   ORDER BY c.\"createdAt\" DESC LIMIT 5;"
echo '== pending claims without telegram'
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT count(*) AS pending_manual_unnotified
   FROM \"PaymentClaim\"
   WHERE status='pending' AND provider='manual' AND \"telegramNotifiedAt\" IS NULL;"
REMOTE
