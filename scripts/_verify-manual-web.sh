#!/usr/bin/env bash
set -euo pipefail
EMAIL=manual-web-1793785500@girlmeet.com
CLAIM=cmw1xjs2m0013qo01sokfwk5j
echo "== wait poller =="
for i in $(seq 1 24); do
  st="$(docker inspect -f '{{.State.Status}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r' || true)"
  echo "  $i $st"
  if [[ "$st" == "running" ]]; then
    break
  fi
  sleep 5
done
echo "== wait approve of $CLAIM =="
for i in $(seq 1 30); do
  if docker logs fg-home-telegram-poll 2>&1 | grep -Fq "handling approve for ${CLAIM}"; then
    echo CALLBACK_OK
    docker logs fg-home-telegram-poll 2>&1 | grep -F "$CLAIM" | tail -8
    break
  fi
  ROW="$(ssh -F /dev/null -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 \
    "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -tAc \"SELECT status FROM \\\"PaymentClaim\\\" WHERE id='${CLAIM}';\"")"
  ROW="$(echo "$ROW" | tr -d '\r' | xargs)"
  echo "  wait $i status=$ROW"
  if [[ "$ROW" == "approved" ]]; then
    echo DB_APPROVED
    break
  fi
  sleep 2
done
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 \
  "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \"
SELECT c.id, c.status, u.email,
  (SELECT count(*) FROM \\\"Subscription\\\" s WHERE s.\\\"userId\\\"=c.\\\"userId\\\" AND s.status='active' AND s.\\\"expiresAt\\\">NOW()) AS active_subs
FROM \\\"PaymentClaim\\\" c JOIN \\\"User\\\" u ON u.id=c.\\\"userId\\\"
WHERE c.id='${CLAIM}';
\""
