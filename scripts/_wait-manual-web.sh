#!/usr/bin/env bash
set -euo pipefail
EMAIL="${1:-manual-web-1793785500@girlmeet.com}"
echo "== poller = $(docker inspect -f '{{.State.Status}}' fg-home-telegram-poll 2>/dev/null | tr -d '\r')"
for i in $(seq 1 40); do
  ROW="$(ssh -F /dev/null -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 \
    "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -tAc \"SELECT c.id||'|'||c.status||'|'||COALESCE(to_char(c.\\\"telegramNotifiedAt\\\",'HH24:MI:SS'),'') FROM \\\"PaymentClaim\\\" c JOIN \\\"User\\\" u ON u.id=c.\\\"userId\\\" WHERE u.email='${EMAIL}' ORDER BY c.\\\"createdAt\\\" DESC LIMIT 1;\"")"
  ROW="$(echo "$ROW" | tr -d '\r' | xargs)"
  echo "try $i: $ROW"
  ID="${ROW%%|*}"
  REST="${ROW#*|}"
  STATUS="${REST%%|*}"
  NOTIFY="${REST##*|}"
  if [[ -n "$ID" && -n "$NOTIFY" ]]; then
    echo "CLAIM_ID=$ID STATUS=$STATUS NOTIFIED=$NOTIFY"
    docker logs fg-home-telegram-poll 2>&1 | grep -F "$ID" | tail -5 || true
    exit 0
  fi
  if [[ -n "$ID" ]] && docker logs fg-home-telegram-poll 2>&1 | grep -Fq "notified claim $ID"; then
    echo "CLAIM_ID=$ID NOTIFIED_IN_LOG"
    exit 0
  fi
  sleep 2
done
echo "TIMEOUT" >&2
docker logs fg-home-telegram-poll --tail 30 2>&1 || true
exit 1
