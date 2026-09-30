#!/bin/bash
set -euo pipefail
cd /opt/fitnessgirl-meet
set -a; source .env; set +a
echo "== public egress =="
curl -4 -sS --max-time 10 https://api.ipify.org; echo
echo "== vk users.get =="
python3 - <<'PY'
import json,urllib.parse,urllib.request,os
token=os.environ.get("VK_ACCESS_TOKEN","")
q=urllib.parse.urlencode({"v":"5.199","access_token":token})
try:
  data=json.load(urllib.request.urlopen("https://api.vk.com/method/users.get?"+q, timeout=20))
except Exception as e:
  print("request_error", e); raise
if "error" in data:
  err=data["error"]
  print("vk_error", err.get("error_code"), err.get("error_msg"))
else:
  print("vk_ok", data.get("response"))
PY
