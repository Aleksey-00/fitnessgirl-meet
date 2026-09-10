#!/bin/sh
set -e
# Tools image: migrations optional (app usually owns migrate)
if [ "${RUN_MIGRATE:-0}" = "1" ]; then
  echo "Running Prisma migrations..."
  npx prisma migrate deploy
fi
exec "$@"
