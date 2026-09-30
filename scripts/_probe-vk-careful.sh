#!/usr/bin/env bash
set -euo pipefail
KEY=/tmp/id_rsa_fg
cp /mnt/c/Users/aazor/.ssh/id_rsa "$KEY"
chmod 600 "$KEY"
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$KEY" root@134.0.113.50 \
  "grep ^VK_ACCESS_TOKEN= /opt/fitnessgirl-meet/.env | head -1" > /tmp/t.env
token=$(sed 's/^VK_ACCESS_TOKEN=//;s/\r$//;s/^"//;s/"$//;s/^'\''//;s/'\''$//' /tmp/t.env)
rm -f /tmp/t.env
echo "len=${#token} sha12=$(printf %s "$token" | sha256sum | awk '{print substr($1,1,12)}')"
echo "quiet 15s..."
sleep 15
python3 <<PY
import json, urllib.parse, urllib.request, time, hashlib
token = """$token"""
print("probe_sha", hashlib.sha256(token.encode()).hexdigest()[:12])

def call(method, **extra):
    params = {"v": "5.199", "access_token": token, **extra}
    q = urllib.parse.urlencode(params)
    data = json.load(urllib.request.urlopen(f"https://api.vk.com/method/{method}?{q}", timeout=25))
    return data

d = call("users.get")
if "error" in d:
    print("users.get ERR", d["error"].get("error_code"), d["error"].get("error_msg"))
else:
    u = d["response"][0]
    print("users.get OK", u.get("id"), u.get("first_name"))

time.sleep(3)
d2 = call(
    "users.search",
    sex="2",
    city="1",
    age_from="25",
    age_to="27",
    has_photo="1",
    count="5",
    fields="sex,photo_200,bdate,city,relation,status,interests,activities,about",
)
if "error" in d2:
    print("users.search ERR", d2["error"].get("error_code"), d2["error"].get("error_msg"))
else:
    r = d2["response"]
    items = r.get("items") or []
    print("users.search OK count", r.get("count"), "items", len(items))
    for i in items[:5]:
        print(" ", i.get("id"), i.get("first_name"), "sex", i.get("sex"))
PY
