#!/usr/bin/env bash
set -euo pipefail
VERIFIER=$(openssl rand -base64 48 | tr -d '=+/' | cut -c1-64)
CHALLENGE=$(printf %s "$VERIFIER" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '=')
STATE=$(openssl rand -hex 16)
printf '%s' "$VERIFIER" > /tmp/fg-vk-verifier.txt
printf '%s' "$STATE" > /tmp/fg-vk-state.txt
printf '%s' "$CHALLENGE" > /tmp/fg-vk-challenge.txt
echo "VERIFIER=$VERIFIER"
echo "CHALLENGE=$CHALLENGE"
echo "STATE=$STATE"
CLIENT_ID=54762470
REDIRECT='https://fitnessgirl-meet.ru'
# URL-encode redirect
REDIR_ENC=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$REDIRECT")
URL="https://id.vk.ru/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIR_ENC}&state=${STATE}&code_challenge=${CHALLENGE}&code_challenge_method=S256"
echo "URL=$URL"
printf '%s' "$URL" > /tmp/fg-vk-auth-url.txt
