#!/usr/bin/env bash
set -euo pipefail
CLAIM_ID="${1:-cmvzo7ho70009qo01ih1v64f9}"
EMAIL="${2:-e2e-tg-1793648837@girlmeet.com}"
echo "Waiting for Telegram approve of $CLAIM_ID ($EMAIL)…"
for i in $(seq 1 120); do
  if docker logs fg-home-telegram-poll 2>&1 | grep -q "handling approve for ${CLAIM_ID}"; then
    echo "LOG_SEEN_APPROVE"
    docker logs fg-home-telegram-poll 2>&1 | grep -E "handling|Подтвержден|error|failed" | tail -20
    break
  fi
  # Also check DB in case message edit lagged but DB updated
  STATUS="$(ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 \
    "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -Atc \"SELECT status FROM \\\"PaymentClaim\\\" WHERE id='${CLAIM_ID}'\"")"
  if [[ "$STATUS" == "approved" ]]; then
    echo "DB_APPROVED"
    break
  fi
  if (( i % 6 == 0 )); then
    echo "still waiting… ($i) status=$STATUS"
  fi
  sleep 5
done

ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 bash -s <<REMOTE
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \
  "SELECT c.id, c.status, u.email, s.status AS sub_status, s.\"expiresAt\"
   FROM \"PaymentClaim\" c
   JOIN \"User\" u ON u.id=c.\"userId\"
   LEFT JOIN \"Subscription\" s ON s.\"userId\"=u.id
   WHERE c.id='${CLAIM_ID}' OR u.email='${EMAIL}'
   ORDER BY s.\"createdAt\" DESC NULLS LAST;"
REMOTE
