#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN='Welcome back|Lorem|dashboard template|demo app|Manage your rides with ease|Your dashboard|AI-generated|Ops dashboard|Fleet Ops|Take rate|On-time|Resolve flow placeholder'

if grep -RInE "$FORBIDDEN" lib test; then
  echo "Forbidden generic UI copy found."
  exit 1
fi

echo "UI copy guard passed."
