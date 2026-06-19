#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PWA_SMOKE_BASE_URL="${PWA_SMOKE_BASE_URL:-https://gold-taxi-clean.web.app}"

cd "$PROJECT_DIR"
node scripts/pwa_browser_smoke.js
