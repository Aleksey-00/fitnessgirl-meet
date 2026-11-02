#!/usr/bin/env bash
set -euo pipefail
EMAIL="${1:-test@girlmeet.com}"

echo "=== systemd bridge ==="
systemctl --user is-active fg-telegram-bridge.service || true
systemctl --user --no-pager status fg-telegram-bridge.service | sed -n '1,20p' || true

echo "=== recent bridge log ==="
tail -n 40 "$HOME/fg-logs/telegram-bridge.log" 2>/dev/null || true

echo "=== prod DB ==="
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<REMOTE
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT id, email, \"createdAt\" FROM \"User\" WHERE email='${EMAIL}';"
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT c.id, c.status, c.provider, c.amount, c.note,
          c.\"telegramNotifiedAt\", c.\"createdAt\"
   FROM \"PaymentClaim\" c
   JOIN \"User\" u ON u.id=c.\"userId\"
   WHERE u.email='${EMAIL}'
   ORDER BY c.\"createdAt\" DESC LIMIT 5;"
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT count(*) AS pending_manual_unnotified
   FROM \"PaymentClaim\"
   WHERE status='pending' AND provider='manual' AND \"telegramNotifiedAt\" IS NULL;"
docker logs fitnessgirl-meet-app-1 --since 30m 2>&1 | grep -iE 'claim|Telegram|telegram|error' | tail -30 || true
REMOTE
