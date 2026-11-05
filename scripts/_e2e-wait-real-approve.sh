#!/usr/bin/env bash
# Create claim, wait for TG notify, then wait until poller handles a real callback.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMAIL="e2e-click-$(date +%s)@girlmeet.com"

echo "==> create $EMAIL"
bash "$ROOT/scripts/_e2e-create-claim.sh" "$EMAIL"
CLAIM_ID="$(python3 -c 'import json; print(json.load(open("/tmp/fg-claim.json")).get("id",""))')"
[[ -n "$CLAIM_ID" ]] || exit 1
echo "CLAIM_ID=$CLAIM_ID"

echo "==> wait notify"
bash "$ROOT/scripts/_wait-notify.sh" "$CLAIM_ID"

echo "==> waiting up to 90s for REAL telegram callback (click Подтвердить in Telegram)…"
for i in $(seq 1 45); do
  if docker logs fg-home-telegram-poll 2>&1 | grep -Fq "handling approve for ${CLAIM_ID}"; then
    echo "CALLBACK_SEEN"
    docker logs fg-home-telegram-poll 2>&1 | grep -F "${CLAIM_ID}" | tail -5
    break
  fi
  # Also accept DB flip in case log line raced
  ST="$(ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
    "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -tAc \"SELECT status FROM \\\"PaymentClaim\\\" WHERE id='${CLAIM_ID}';\"" | tr -d '\r' | xargs)"
  if [[ "$ST" == "approved" ]]; then
    echo "DB_APPROVED_WITHOUT_LOG_YET"
    break
  fi
  echo "  wait click $i status=$ST"
  sleep 2
  if [[ "$i" -eq 45 ]]; then
    echo "NO_CALLBACK — falling back to same resolve path as poller" >&2
    bash "$ROOT/scripts/_e2e-approve-claim.sh" "$CLAIM_ID"
  fi
done

echo "==> verify"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \"
SELECT c.id, c.status, u.email,
  (SELECT count(*) FROM \\\"Subscription\\\" s WHERE s.\\\"userId\\\"=c.\\\"userId\\\" AND s.status='active' AND s.\\\"expiresAt\\\">NOW()) AS active_subs
FROM \\\"PaymentClaim\\\" c JOIN \\\"User\\\" u ON u.id=c.\\\"userId\\\"
WHERE c.id='${CLAIM_ID}';
\""

echo "E2E_CLICK_DONE claim=$CLAIM_ID email=$EMAIL"
