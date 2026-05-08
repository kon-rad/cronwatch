#!/usr/bin/env bash
#
# Runs ON the droplet, invoked by deploy.sh after rsync.
#
# Steps:
#   1. npm install (incl. dev deps so we can run tsc)
#   2. npm run build
#   3. prune dev deps (smaller process footprint)
#   4. pm2 startOrReload ecosystem.config.cjs
#   5. pm2 save
#
# Argument: PM2 process name (defaults to "cronwatch-server").

set -euo pipefail

SERVICE_NAME="${1:-cronwatch-server}"
APP_DIR="/opt/cronwatch-server"

cd "$APP_DIR"

if [[ ! -f .env ]]; then
  echo "✗ Missing $APP_DIR/.env — refusing to deploy." >&2
  exit 1
fi

echo "▶︎ Installing dependencies (with dev for build)"
npm install --no-audit --no-fund --include=dev

echo "▶︎ Building TypeScript"
npm run build

echo "▶︎ Pruning to production dependencies"
npm prune --omit=dev

echo "▶︎ Reloading PM2 ($SERVICE_NAME)"
# startOrReload is the idempotent form: starts if missing, zero-downtime
# reloads if already running. --update-env re-reads .env on every deploy.
pm2 startOrReload ecosystem.config.cjs --update-env

pm2 save >/dev/null
echo "✓ remote-deploy.sh done"
