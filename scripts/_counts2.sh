#!/bin/bash
set -e
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c 'SELECT "photoGender", "isHidden", count(*) FROM "Profile" GROUP BY 1,2 ORDER BY 1,2;'
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c 'SELECT "photoGender", "photoAgeStatus", count(*) FROM "Profile" WHERE "photoGender" = '\''male'\'' OR "photoAgeStatus" = '\''male'\'' GROUP BY 1,2;'
