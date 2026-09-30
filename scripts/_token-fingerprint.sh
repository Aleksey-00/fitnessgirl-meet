#!/usr/bin/env bash
set -euo pipefail
KEY=/tmp/id_rsa_fg
cp /mnt/c/Users/aazor/.ssh/id_rsa "$KEY"
chmod 600 "$KEY"
python3 <<'PY'
from pathlib import Path
import hashlib, subprocess

def fp(s: str) -> str:
    s = (s or "").strip().strip('"').strip("'")
    if not s:
        return "EMPTY"
    return f"len={len(s)} sha12={hashlib.sha256(s.encode()).hexdigest()[:12]} head={s[:6]}…tail={s[-4:]}"

def read_tok(path: Path) -> str:
    if not path.exists():
        return ""
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("VK_ACCESS_TOKEN="):
            return line.split("=", 1)[1]
    return ""

for p in [
    Path("/mnt/c/projects/fitnessgirl-meet/.env"),
    Path("/mnt/c/projects/fitnessgirl-meet/.env.local"),
]:
    print("LOCAL", p, fp(read_tok(p)) if p.exists() else "missing")

out = subprocess.check_output(
    [
        "ssh", "-F", "/dev/null", "-o", "StrictHostKeyChecking=no", "-i", "/tmp/id_rsa_fg",
        "root@134.0.113.50",
        "grep ^VK_ACCESS_TOKEN= /opt/fitnessgirl-meet/.env | head -1",
    ],
    text=True,
)
tok = out.split("=", 1)[1] if "=" in out else ""
print("VPS", fp(tok))
PY
