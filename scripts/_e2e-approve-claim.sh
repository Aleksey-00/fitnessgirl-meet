#!/usr/bin/env bash
# Approve a pending claim through the same resolve path the TG poller uses.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAIM_ID="${1:?claim id}"

DBURL="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^DATABASE_URL=//p')"
TOKEN="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^TELEGRAM_BOT_TOKEN=//p')"
CHAT="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^TELEGRAM_ADMIN_CHAT_ID=//p')"
DAYS="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^SUBSCRIPTION_DAYS=//p')"
DAYS="${DAYS:-30}"
[[ -n "$DBURL" ]] || { echo "poller not running / no DATABASE_URL" >&2; exit 1; }

docker run --rm \
  -v "$ROOT/scripts:/app/scripts:ro" \
  -e DATABASE_URL="$DBURL" \
  -e TELEGRAM_BOT_TOKEN="$TOKEN" \
  -e TELEGRAM_ADMIN_CHAT_ID="$CHAT" \
  -e SUBSCRIPTION_DAYS="$DAYS" \
  -e CLAIM_ID="$CLAIM_ID" \
  fitnessgirl-meet-indexer:latest \
  npx tsx /app/scripts/_e2e-approve-once.mjs

ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \"
SELECT c.id, c.status, u.email,
  (SELECT count(*) FROM \\\"Subscription\\\" s WHERE s.\\\"userId\\\"=c.\\\"userId\\\" AND s.status='active' AND s.\\\"expiresAt\\\">NOW()) AS active_subs
FROM \\\"PaymentClaim\\\" c JOIN \\\"User\\\" u ON u.id=c.\\\"userId\\\"
WHERE c.id='${CLAIM_ID}';
\""
