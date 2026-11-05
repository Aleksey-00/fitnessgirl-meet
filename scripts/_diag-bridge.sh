#!/usr/bin/env bash
set -uo pipefail
echo "== pgrep =="
pgrep -af 'run-home-telegram|telegram-poll|fg-telegram' || true
echo "== docker =="
docker ps -a --filter name=fg-home --format 'table {{.ID}}\t{{.Status}}\t{{.Names}}' || true
echo "== logs =="
docker logs fg-home-telegram-poll --tail 50 2>&1 || true
echo "== flock =="
ls -la /tmp/fg-telegram* 2>/dev/null || true
fuser /tmp/fg-telegram-bridge.lock 2>/dev/null || true
echo "== claim =="
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "SELECT id, status, \"telegramNotifiedAt\" FROM \"PaymentClaim\" WHERE id='"'"'cmw1wg2t5000iqo015dn8y6um'"'"'; SELECT id, email, status FROM \"Subscription\" WHERE email ILIKE '"'"'%e2e-tg-1793783604%'"'"' OR email ILIKE '"'"'%girltest%'"'"' ORDER BY \"createdAt\" DESC LIMIT 10;"'
