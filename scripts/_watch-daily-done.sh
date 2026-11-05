#!/usr/bin/env bash
set -uo pipefail
echo "[watch] waiting for daily index to finish"
while systemctl --user is-active --quiet fg-indexer-daily.service 2>/dev/null \
  || pgrep -f 'index-vk.ts --daily' >/dev/null 2>&1; do
  sleep 60
done
echo "DAILY_INDEX_FINISHED_3"
tail -n 30 /home/aazor/fg-logs/indexer-daily.log || true
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${HOME}/.ssh/id_rsa" root@134.0.113.50 \
  'cd /opt/fitnessgirl-meet && docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "SELECT \"photoGender\", count(*) FILTER (WHERE NOT \"isHidden\") AS visible FROM \"Profile\" GROUP BY 1 ORDER BY 1;"'
