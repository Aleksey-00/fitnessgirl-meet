#!/usr/bin/env bash
# Full E2E: bridge up → create claim → wait notify → approve via same resolve path → verify.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMAIL="e2e-tg-$(date +%s)@girlmeet.com"

echo "==> unit logic"
node "$ROOT/scripts/_test-telegram-poll-logic.mjs"

echo "==> bridge must be running"
systemctl --user is-active fg-telegram-bridge.service
for i in $(seq 1 30); do
  st="$(docker inspect -f '{{.State.Status}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r' || true)"
  if [[ "$st" == "running" ]]; then
    echo "poller running"
    break
  fi
  if [[ "$i" -eq 30 ]]; then
    echo "poller not running" >&2
    systemctl --user --no-pager status fg-telegram-bridge.service | sed -n '1,25p' || true
    docker logs fg-home-telegram-poll --tail 40 2>&1 || true
    exit 1
  fi
  sleep 2
done

echo "==> create claim via API ($EMAIL)"
bash "$ROOT/scripts/_e2e-create-claim.sh" "$EMAIL"
CLAIM_ID="$(python3 -c 'import json; print(json.load(open("/tmp/fg-claim.json")).get("id",""))')"
[[ -n "$CLAIM_ID" ]] || { echo "no claim id" >&2; exit 1; }
echo "CLAIM_ID=$CLAIM_ID"

echo "==> wait telegramNotifiedAt (up to 60s)"
NOTIFIED=0
for i in $(seq 1 30); do
  ROW="$(ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 \
    "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -tAc \"SELECT COALESCE(to_char(\\\"telegramNotifiedAt\\\",'YYYY-MM-DD HH24:MI:SS'),'')||'|'||status FROM \\\"PaymentClaim\\\" WHERE id='${CLAIM_ID}';\"")"
  ROW="$(echo "$ROW" | tr -d '\r' | xargs)"
  echo "  try $i: $ROW"
  NOTIFY_TS="${ROW%%|*}"
  STATUS="${ROW##*|}"
  if [[ -n "$NOTIFY_TS" && "$STATUS" == "pending" ]]; then
    NOTIFIED=1
    break
  fi
  sleep 2
done
if [[ "$NOTIFIED" != "1" ]]; then
  echo "NOT NOTIFIED" >&2
  docker logs fg-home-telegram-poll --tail 50 2>&1 || true
  exit 1
fi
echo "NOTIFIED_OK at $NOTIFY_TS"

echo "==> simulate Telegram approve (same SQL path as poller)"
# Run resolve inside the poller image against the live tunnel DB.
# Extract env from running poller container.
DBURL="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^DATABASE_URL=//p')"
TOKEN="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^TELEGRAM_BOT_TOKEN=//p')"
CHAT="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^TELEGRAM_ADMIN_CHAT_ID=//p')"
DAYS="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' fg-home-telegram-poll | tr -d '\r' | sed -n 's/^SUBSCRIPTION_DAYS=//p')"
DAYS="${DAYS:-30}"

docker run --rm \
  -v "$ROOT/scripts:/app/scripts:ro" \
  -e DATABASE_URL="$DBURL" \
  -e TELEGRAM_BOT_TOKEN="$TOKEN" \
  -e TELEGRAM_ADMIN_CHAT_ID="$CHAT" \
  -e SUBSCRIPTION_DAYS="$DAYS" \
  -e CLAIM_ID="$CLAIM_ID" \
  fitnessgirl-meet-indexer:latest \
  npx tsx /app/scripts/_e2e-approve-once.mjs

echo "==> verify DB"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<REMOTE
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT c.id, c.status, u.email, (SELECT count(*) FROM \"Subscription\" s WHERE s.\"userId\"=c.\"userId\" AND s.status='active' AND s.\"expiresAt\">NOW()) AS active_subs FROM \"PaymentClaim\" c JOIN \"User\" u ON u.id=c.\"userId\" WHERE c.id='${CLAIM_ID}';"
REMOTE

echo "E2E_OK email=$EMAIL claim=$CLAIM_ID"
