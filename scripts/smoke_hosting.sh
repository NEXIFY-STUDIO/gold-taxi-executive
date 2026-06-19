#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-https://gold-taxi-clean.web.app}"

curl -fsSI "$BASE_URL/home" | grep -E 'HTTP/2 200|HTTP/1.1 200' >/dev/null
curl -fsSI "$BASE_URL/app" | grep -E 'HTTP/2 200|HTTP/1.1 200' >/dev/null
curl -fsS "$BASE_URL/manifest.json" >/dev/null
curl -fsS "$BASE_URL/robots.txt" >/dev/null
curl -fsS "$BASE_URL/sitemap.xml" >/dev/null

echo "Hosting smoke passed: $BASE_URL"
