#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=25 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 bash -s <<'REMOTE'
set -euxo pipefail
cd /opt/fitnessgirl-meet
sed -i 's/\r$//' docker/entrypoint.sh docker/entrypoint-tools.sh scripts/daily-indexer-loop.sh || true
set -a
source .env
set +a
echo "== build tools =="
docker compose --profile tools build indexer
echo "== run daily =="
docker compose --profile tools run --rm indexer
echo "== counts after =="
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "SELECT \"photoGender\", \"isHidden\", count(*) FROM \"Profile\" GROUP BY 1,2 ORDER BY 1,2;"
echo DONE_DAILY_OK
REMOTE
