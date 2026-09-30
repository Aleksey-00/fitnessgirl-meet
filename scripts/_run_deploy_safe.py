#!/usr/bin/env python3
"""Clash-safe deploy: rsync + remote rebuild. Never touches Clash."""
import subprocess
import sys
from pathlib import Path

ROOT = Path("/mnt/c/projects/fitnessgirl-meet")
VPS = "root@134.0.113.50"
KEY = str(Path.home() / ".ssh" / "id_rsa")
REMOTE = "/opt/fitnessgirl-meet"

SSH_BASE = [
    "ssh", "-F", "/dev/null",
    "-o", "StrictHostKeyChecking=no",
    "-o", "ConnectTimeout=30",
    "-o", "ServerAliveInterval=15",
    "-i", KEY,
    VPS,
]


def run(cmd, check=True):
    print("+", " ".join(cmd), flush=True)
    r = subprocess.run(cmd)
    if check and r.returncode != 0:
        raise SystemExit(r.returncode)
    return r.returncode


def main():
    for rel in ["docker/entrypoint.sh", "docker/entrypoint-tools.sh"]:
        p = ROOT / rel
        if p.exists():
            data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
            p.write_bytes(data)
            print("lf-fixed", p, flush=True)

    print("==> sync", flush=True)
    run([
        "rsync", "-az",
        "--exclude", ".git",
        "--exclude", "node_modules",
        "--exclude", ".nuxt",
        "--exclude", ".output",
        "--exclude", ".env",
        "--exclude", "models",
        "--exclude", "*.log",
        "--exclude", "scripts/_*.sh",
        "--exclude", "scripts/_*.ps1",
        "--exclude", "scripts/_*.mjs",
        "--exclude", "scripts/_*.js",
        "--exclude", "scripts/_*.ts",
        "--exclude", "scripts/_*.py",
        "-e", f"ssh -F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -i {KEY}",
        f"{ROOT}/",
        f"{VPS}:{REMOTE}/",
    ])

    remote_script = r'''
set -euo pipefail
cd /opt/fitnessgirl-meet
python3 -c "from pathlib import Path
for rel in ['docker/entrypoint.sh','docker/entrypoint-tools.sh','scripts/daily-indexer-loop.sh']:
 p=Path(rel)
 if p.exists():
  p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n').replace(b'\r',b'\n')); print('lf',rel)"
echo "== migrate"
docker compose run --rm --no-deps -T --entrypoint sh app -c "npx prisma migrate deploy" </dev/null
echo "== rebuild app"
docker compose up -d --build app
echo "== wait health"
for i in $(seq 1 40); do
  if curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    echo HEALTH_OK
    curl -fsS http://127.0.0.1:3000/api/health; echo
    break
  fi
  sleep 5
  echo "wait $i..."
done
docker compose ps
echo "== smoke"
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=female" | head -c 200; echo
curl -fsS "http://127.0.0.1:3000/api/profiles?limit=1&gender=male" | head -c 200; echo
echo DONE_REMOTE
'''

    print("==> remote rebuild", flush=True)
    r = subprocess.run(SSH_BASE + ["bash", "-s"], input=remote_script.encode())
    if r.returncode != 0:
        raise SystemExit(r.returncode)
    print("DONE_DEPLOY", flush=True)


if __name__ == "__main__":
    main()
