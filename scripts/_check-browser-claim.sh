#!/usr/bin/env bash
set -euo pipefail
echo "== poller =="
docker inspect -f '{{.State.Status}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r' || true
docker logs fg-home-telegram-poll --tail 40 2>&1 || true
echo "== db =="
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "SELECT c.id, c.status, c.\"telegramNotifiedAt\", c.note, u.email FROM \"PaymentClaim\" c JOIN \"User\" u ON u.id=c.\"userId\" ORDER BY c.\"createdAt\" DESC LIMIT 10;"'
