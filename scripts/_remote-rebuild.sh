#!/bin/bash
set -euo pipefail
cd /opt/fitnessgirl-meet
sed -i "s/\r$//" docker/entrypoint.sh docker/entrypoint-tools.sh 2>/dev/null || true
echo "== rebuild app =="
docker compose up -d --build app
echo "== wait health =="
for i in $(seq 1 40); do
  if curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    echo HEALTH_OK
    curl -fsS http://127.0.0.1:3000/api/health; echo
    break
  fi
  sleep 5
  echo "wait $i..."
done
docker compose ps
echo "== catalog.vue gender lines =="
grep -n "gender\|Девуш\|Парн\|catalogGender" pages/catalog.vue | head -30 || true
echo "== API female =="
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=female"; echo
echo "== API male =="
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=male"; echo
echo "== public health =="
curl -fsS --max-time 10 https://fitnessgirl-meet.ru/api/health; echo
echo REBUILD_DONE