#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
curl -fsS http://127.0.0.1:3000/api/payments/info
echo
docker exec fitnessgirl-meet-app-1 grep invId /app/node_modules/.prisma/client/schema.prisma | sed -n '1,2p'
# Ensure no pending claim blocks test user; just show recent claims
docker compose -f /opt/fitnessgirl-meet/docker-compose.yml exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT u.email, c.status, c.provider, c.\"telegramNotifiedAt\" IS NOT NULL AS tg, c.\"createdAt\" FROM \"PaymentClaim\" c JOIN \"User\" u ON u.id=c.\"userId\" WHERE u.email='test222test@mail.com' ORDER BY c.\"createdAt\" DESC LIMIT 5;"
REMOTE
