#!/usr/bin/env bash
set -euo pipefail
ssh -F /dev/null -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa" root@134.0.113.50 'bash -s' <<'REMOTE'
set -euo pipefail
cd /opt/fitnessgirl-meet
ls -la | head -40
echo '--- prisma migrations ---'
ls -la prisma/migrations 2>&1 | head -20
echo '--- partners ---'
ls -la pages/partners.vue 2>&1
echo '--- schema gender ---'
grep -n 'enum Gender\|gender' prisma/schema.prisma | head
echo '--- .env exists ---'
test -f .env && echo YES_ENV || echo NO_ENV
REMOTE
