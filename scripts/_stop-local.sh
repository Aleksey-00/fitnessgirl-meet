#!/usr/bin/env bash
set -euo pipefail
# Stop leftover local docker app/indexer (keep nothing for local QA)
cd /mnt/c/projects/fitnessgirl-meet
docker compose -f docker-compose.yml -f docker-compose.dev.yml stop app 2>/dev/null || true
docker compose -f docker-compose.yml -f docker-compose.dev.yml stop db 2>/dev/null || true
docker rm -f $(docker ps -aq --filter name=fitnessgirl-meet) 2>/dev/null || true
pkill -f 'nuxt|index-vk|telegram-poll|run-home-indexer' 2>/dev/null || true
echo LOCAL_DOCKER_STOPPED
