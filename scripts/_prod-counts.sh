#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
  -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
docker compose exec -T db psql -U fitnessgirl -d fitnessgirl <<'SQL'
SELECT "photoGender",
       count(*) FILTER (WHERE "isHidden"=false AND "photoAgeStatus"='ok') AS visible_ok,
       count(*) AS total
FROM "Profile"
GROUP BY 1
ORDER BY 1;

SELECT count(*) AS users, (SELECT count(*) FROM "Subscription") AS subs, (SELECT count(*) FROM "PaymentClaim") AS claims
FROM "User";

SELECT email, role FROM "User";
SQL
REMOTE
