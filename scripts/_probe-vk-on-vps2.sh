#!/usr/bin/env bash
set -euo pipefail
KEY=/tmp/id_rsa_fg
cp /mnt/c/Users/aazor/.ssh/id_rsa "$KEY"
chmod 600 "$KEY"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$KEY" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
set -a; source .env; set +a
echo -n "vps_egress="; curl -4 -sS --max-time 8 https://api.ipify.org; echo
python3 <<'PY'
import json, urllib.parse, urllib.request, os
token = os.environ.get("VK_ACCESS_TOKEN", "")
print("token_len", len(token))
for method, extra in [
    ("users.get", {}),
    ("users.search", {"q": "александр", "sex": "2", "city": "1", "age_from": "25", "age_to": "26", "count": "3", "has_photo": "1"}),
]:
    params = {"v": "5.199", "access_token": token, **extra}
    q = urllib.parse.urlencode(params)
    data = json.load(urllib.request.urlopen(f"https://api.vk.com/method/{method}?{q}", timeout=20))
    if "error" in data:
        e = data["error"]
        print(method, "ERR", e.get("error_code"), e.get("error_msg"))
    else:
        r = data["response"]
        if method == "users.search":
            print(method, "OK count", r.get("count"), "items", len(r.get("items") or []))
        else:
            u = (r or [{}])[0]
            print(method, "OK id", u.get("id"), u.get("first_name"))
PY
REMOTE
