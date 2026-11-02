#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<'SQL'
SELECT column_name FROM information_schema.columns
WHERE table_name = 'PaymentClaim' ORDER BY ordinal_position;
SELECT migration_name, finished_at FROM _prisma_migrations ORDER BY finished_at;
SQL
echo '--- env robokassa ---'
grep -E '^ROBOKASSA_|^TELEGRAM_' .env | sed 's/=.*/=***/'
echo '--- telegram process ---'
ps aux | grep -E 'telegram-poll|run-home-telegram' | grep -v grep || echo 'no home telegram on vps (expected)'
REMOTE
