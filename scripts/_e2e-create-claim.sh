#!/usr/bin/env bash
# Create E2E user + pending manual claim via public API on prod.
set -euo pipefail
EMAIL="${1:-e2e-tg-$(date +%s)@girlmeet.com}"
PASS_PLAIN="${2:-E2eTestPass123!}"
SITE="${FG_SITE:-https://fitnessgirl-meet.ru}"
COOKIE_JAR="$(mktemp)"
# Same as browser login form: SHA-256 hex of password.
PASS="$(python3 - <<PY
import hashlib
print(hashlib.sha256('''$PASS_PLAIN'''.encode()).hexdigest())
PY
)"

echo "EMAIL=$EMAIL"
echo "== register"
REG_CODE="$(curl -sS -o /tmp/fg-reg.json -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -H 'content-type: application/json' \
  -X POST "$SITE/api/auth/register" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"gender\":\"male\"}")"
echo "register_http=$REG_CODE body=$(head -c 300 /tmp/fg-reg.json)"

if [[ "$REG_CODE" != "200" && "$REG_CODE" != "201" ]]; then
  echo "== login (user may already exist)"
  curl -sS -c "$COOKIE_JAR" -b "$COOKIE_JAR" -H 'content-type: application/json' \
    -X POST "$SITE/api/auth/login" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" | head -c 300
  echo
fi

echo "== claim"
CLAIM_CODE="$(curl -sS -o /tmp/fg-claim.json -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -H 'content-type: application/json' \
  -X POST "$SITE/api/payments/claim" \
  -d '{"note":"e2e telegram approve test"}')"
echo "claim_http=$CLAIM_CODE body=$(cat /tmp/fg-claim.json)"
rm -f "$COOKIE_JAR"

if [[ "$CLAIM_CODE" != "200" ]]; then
  echo "CLAIM_FAILED" >&2
  exit 1
fi
echo "CLAIM_OK email=$EMAIL"
echo "$EMAIL" > /tmp/fg-e2e-email.txt
python3 - <<PY
import json
print("CLAIM_ID=" + json.load(open("/tmp/fg-claim.json")).get("id",""))
PY
