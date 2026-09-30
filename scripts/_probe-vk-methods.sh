#!/usr/bin/env bash
set -euo pipefail
KEY=/tmp/id_rsa_fg
VPS=root@134.0.113.50
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$KEY" "$VPS" \
  "grep ^VK_ACCESS_TOKEN= /opt/fitnessgirl-meet/.env | head -1" > /tmp/fg.tok.env
token=$(sed 's/^VK_ACCESS_TOKEN=//;s/\r//;s/^"//;s/"$//;s/^'\''//;s/'\''$//' /tmp/fg.tok.env)
rm -f /tmp/fg.tok.env
echo "token_len=${#token} ip=$(curl -4 -sS --max-time 8 https://api.ipify.org)"
python3 <<PY
import json, urllib.parse, urllib.request
token = """$token"""
checks = [
  ("users.get", {"v": "5.199", "access_token": token}),
  ("users.search", {
    "v": "5.199", "access_token": token, "q": "александр", "sex": "2",
    "city": "1", "age_from": "25", "age_to": "25", "count": "3", "has_photo": "1",
  }),
]
for method, params in checks:
  q = urllib.parse.urlencode(params)
  try:
    data = json.load(urllib.request.urlopen(f"https://api.vk.com/method/{method}?{q}", timeout=20))
  except Exception as e:
    print(method, "REQ_ERR", e)
    continue
  if "error" in data:
    err = data["error"]
    print(method, "ERR", err.get("error_code"), err.get("error_msg"))
  else:
    r = data.get("response")
    if method == "users.search":
      print(method, "OK count", (r or {}).get("count"), "items", len((r or {}).get("items") or []))
    else:
      print(method, "OK")
PY
