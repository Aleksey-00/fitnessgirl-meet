#!/usr/bin/env bash
set -euo pipefail
CLAIM_ID="${1:?claim id}"
for i in $(seq 1 30); do
  if docker logs fg-home-telegram-poll 2>&1 | grep -Fq "notified claim ${CLAIM_ID}"; then
    echo "NOTIFIED_IN_LOG"
    docker logs fg-home-telegram-poll 2>&1 | grep -F "${CLAIM_ID}" | tail -5
    break
  fi
  echo "wait $i"
  sleep 2
  if [[ "$i" -eq 30 ]]; then
    echo "TIMEOUT" >&2
    docker logs fg-home-telegram-poll --tail 40 2>&1 || true
    exit 1
  fi
done
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" root@134.0.113.50 \
  "cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c \"SELECT id, status, \\\"telegramNotifiedAt\\\" FROM \\\"PaymentClaim\\\" WHERE id='${CLAIM_ID}';\""
