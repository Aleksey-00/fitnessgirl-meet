#!/bin/bash
set -euo pipefail
cd /opt/fitnessgirl-meet

echo "== before =="
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c 'SELECT count(*) AS total FROM "Profile";'
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c "SELECT count(*) AS catalog_ok FROM \"Profile\" WHERE \"isHidden\"=false AND \"photoGender\" IN ('female','male') AND \"photoAgeStatus\"='ok' AND age BETWEEN 18 AND 35 AND (signals->>'sport')='true' AND (signals->>'activelyLooking')='true';"

echo "== delete non-catalog profiles =="
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1 -c "
DELETE FROM \"Profile\"
WHERE NOT (
  \"isHidden\" = false
  AND \"photoGender\" IN ('female', 'male')
  AND \"photoAgeStatus\" = 'ok'
  AND age BETWEEN 18 AND 35
  AND (signals->>'sport') = 'true'
  AND (signals->>'activelyLooking') = 'true'
);
"

echo "== delete test users (cascade subs/claims) =="
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -v ON_ERROR_STOP=1 -c "
DELETE FROM \"User\"
WHERE lower(email) LIKE 'test%'
   OR lower(split_part(email, '@', 1)) LIKE 'test%';
"

echo "== after =="
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl -c '
SELECT "photoGender", count(*) FROM "Profile" GROUP BY 1 ORDER BY 1;
SELECT id, email, role FROM "User" ORDER BY email;
SELECT count(*) AS subscriptions FROM "Subscription";
SELECT count(*) AS claims FROM "PaymentClaim";
'
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=1&gender=female' | python3 -c 'import sys,json; d=json.load(sys.stdin); print("api_female", d.get("total"), "locked", d.get("lockedCount"))'
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=1&gender=male' | python3 -c 'import sys,json; d=json.load(sys.stdin); print("api_male", d.get("total"))'
echo CLEAN_DONE
