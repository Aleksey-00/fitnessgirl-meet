#!/usr/bin/env bash
set -euo pipefail
cd /opt/fitnessgirl-meet
echo "== seed prisma engine cache"
rm -rf _prisma_engine_cache/prisma _prisma_engine_cache/engines
mkdir -p _prisma_engine_cache
docker cp fitnessgirl-meet-app-1:/app/node_modules/.prisma/. _prisma_engine_cache/prisma/
docker cp fitnessgirl-meet-app-1:/app/node_modules/@prisma/engines/. _prisma_engine_cache/engines/ || true
ls -la _prisma_engine_cache/prisma/client/libquery_engine-debian-openssl-3.0.x.so.node
if [ -f _prisma_client_overlay/schema.prisma ]; then
  grep -q invId _prisma_client_overlay/schema.prisma
  echo "overlay has invId ($(ls _prisma_client_overlay | wc -l) files)"
else
  echo "WARN: _prisma_client_overlay missing"
fi
# Keep Robokassa public checkout off until shop activation is confirmed.
if ! grep -qE '^ROBOKASSA_ENABLED=' .env 2>/dev/null; then
  echo 'ROBOKASSA_ENABLED=0' >> .env
  echo "appended ROBOKASSA_ENABLED=0"
else
  sed -i 's/^ROBOKASSA_ENABLED=.*/ROBOKASSA_ENABLED=0/' .env
  echo "set ROBOKASSA_ENABLED=0"
fi
python3 - <<'PY'
from pathlib import Path
for rel in ["Dockerfile", "docker/entrypoint.sh", "docker/entrypoint-tools.sh"]:
    p = Path(rel)
    if p.exists():
        p.write_bytes(p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
        print("lf-fixed", rel)
PY
echo "== rebuild app"
docker compose up -d --build app
echo "== wait health"
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    echo HEALTH_OK
    curl -fsS http://127.0.0.1:3000/api/health
    echo
    break
  fi
  sleep 5
  echo "wait $i..."
done
docker inspect fitnessgirl-meet-app-1 --format 'created={{.Created}} image={{.Image}}'
docker compose ps
echo "== smoke payments info"
curl -fsS http://127.0.0.1:3000/api/payments/info; echo
echo REBUILD_DONE
