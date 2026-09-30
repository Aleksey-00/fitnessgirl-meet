#!/usr/bin/env bash
set -euo pipefail
echo '== female =='
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=5&gender=female'
echo
echo '== male =='
curl -fsS 'http://127.0.0.1:3000/api/profiles?limit=5&gender=male'
echo
