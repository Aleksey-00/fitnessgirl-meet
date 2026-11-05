#!/usr/bin/env bash
set -euo pipefail
CLAIM_ID="${1:-cmw1vvklu000cqo01v556arp3}"

echo "==> clear telegramNotifiedAt for ${CLAIM_ID}"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<REMOTE
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1 \
  -c "UPDATE \"PaymentClaim\" SET \"telegramNotifiedAt\" = NULL, \"updatedAt\" = NOW() WHERE id = '${CLAIM_ID}' AND status = 'pending';" \
  -c "SELECT id, status, \"telegramNotifiedAt\" FROM \"PaymentClaim\" WHERE id = '${CLAIM_ID}';"
REMOTE

echo "==> restart fg-telegram-bridge"
systemctl --user restart fg-telegram-bridge.service
sleep 25
echo "==> status"
systemctl --user is-active fg-telegram-bridge.service
docker inspect -f 'status={{.State.Status}} started={{.State.StartedAt}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r' || echo 'no container'
echo "==> poll logs"
docker logs fg-home-telegram-poll --tail 40 2>&1 || true
