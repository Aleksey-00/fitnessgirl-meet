#!/usr/bin/env bash
# Install systemd user timer: daily both-sexes VK index from home → prod DB.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
LOG_DIR="$HOME/fg-logs"
mkdir -p "$UNIT_DIR" "$LOG_DIR"

sed -i 's/\r$//' \
  "$ROOT/scripts/run-home-daily-both.sh" \
  "$ROOT/scripts/_run-home-indexer-dockerdesk.sh" \
  "$ROOT/scripts/fg-indexer-daily.service" \
  "$ROOT/scripts/fg-indexer-daily.timer" \
  "$ROOT/scripts/index-vk.ts" || true
chmod +x "$ROOT/scripts/run-home-daily-both.sh" "$ROOT/scripts/_run-home-indexer-dockerdesk.sh"

sed 's/\r$//' "$ROOT/scripts/fg-indexer-daily.service" >"$UNIT_DIR/fg-indexer-daily.service"
sed 's/\r$//' "$ROOT/scripts/fg-indexer-daily.timer" >"$UNIT_DIR/fg-indexer-daily.timer"
chmod 644 "$UNIT_DIR/fg-indexer-daily.service" "$UNIT_DIR/fg-indexer-daily.timer"

if loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes'; then
  echo "Linger=yes"
elif sudo -n loginctl enable-linger "$USER" 2>/dev/null; then
  echo "Linger enabled"
else
  echo "WARN: Linger not set — Windows logon task should wake WSL"
fi

# Keep VPS indexer-daily OFF: user token is IP-bound to this machine.
ssh -F /dev/null -o StrictHostKeyChecking=no -i "${FG_SSH_KEY:-$HOME/.ssh/id_rsa}" "${FG_VPS:-root@134.0.113.50}" bash -s <<'REMOTE' || true
cd /opt/fitnessgirl-meet
docker compose --profile cron stop indexer-daily >/dev/null 2>&1 || true
docker compose --profile cron rm -f indexer-daily >/dev/null 2>&1 || true
# Document intent in .env (VPS cron still must not run with IP-bound token).
grep -q '^VK_INDEX_SEX=' .env && sed -i 's/^VK_INDEX_SEX=.*/VK_INDEX_SEX=both/' .env || echo 'VK_INDEX_SEX=both' >> .env
grep -q '^VK_DAILY_LIMIT=' .env || echo 'VK_DAILY_LIMIT=100' >> .env
echo "vps: indexer-daily stopped; VK_INDEX_SEX=both"
REMOTE

systemctl --user daemon-reload
systemctl --user enable --now fg-indexer-daily.timer
systemctl --user --no-pager status fg-indexer-daily.timer || true
systemctl --user list-timers 'fg-indexer-daily.timer' --no-pager || true

echo
echo "OK: home daily BOTH sexes scheduled"
echo "Log: $LOG_DIR/indexer-daily.log"
echo "Manual now:  systemctl --user start fg-indexer-daily.service"
echo "Or:          bash $ROOT/scripts/run-home-daily-both.sh"
