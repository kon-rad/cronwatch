#!/usr/bin/env bash
# Build and deploy the Cronwatch landing page to the DigitalOcean droplet.
#
# Usage (from the web/ directory or anywhere in the repo):
#   ./deploy/deploy.sh                    # build + ship + restart
#   ./deploy/deploy.sh --skip-build       # ship the existing .next/standalone
#   ./deploy/deploy.sh --setup            # run setup-server.sh after upload
#                                           (first deploy / config changes)
#
# Connection: override defaults with env vars:
#   SSH_HOST=root@1.2.3.4 ./deploy/deploy.sh
#   SSH_KEY=~/.ssh/mykey  ./deploy/deploy.sh

set -euo pipefail

SSH_HOST="${SSH_HOST:-root@68.183.142.183}"
SSH_KEY="${SSH_KEY:-~/.ssh/2026_do}"
APP_NAME="cronwatch-web"
REMOTE_DIR="/opt/${APP_NAME}"

# Resolve the web/ directory regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$WEB_DIR"

# Build SSH/rsync connection options.
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY")
fi

ssh_run() {
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" "$@"
}

rsync_opts() {
  local rsh="ssh -o StrictHostKeyChecking=accept-new"
  if [[ -n "$SSH_KEY" ]]; then
    rsh="$rsh -i $SSH_KEY"
  fi
  printf '%s' "$rsh"
}

SKIP_BUILD=0
RUN_SETUP=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --setup)      RUN_SETUP=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"; exit 0 ;;
    *)
      echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "==> Installing dependencies"
  npm ci

  echo "==> Building Next.js (standalone)"
  npm run build
fi

if [ ! -d ".next/standalone" ]; then
  echo "ERROR: .next/standalone not found. next.config.ts must set output: 'standalone'." >&2
  exit 1
fi

# The standalone build emits a self-contained server.js + minimal node_modules
# at .next/standalone, but it does NOT copy public/ or .next/static — those
# need to be placed alongside server.js by the deploy.
echo "==> Staging build for transfer"
STAGE_DIR="$(mktemp -d -t cronwatch-web-XXXXXX)"
trap 'rm -rf "$STAGE_DIR"' EXIT

cp -R .next/standalone/. "$STAGE_DIR/"
mkdir -p "$STAGE_DIR/.next"
cp -R .next/static "$STAGE_DIR/.next/static"
if [ -d public ]; then
  cp -R public "$STAGE_DIR/public"
fi
# Ship the deploy/ directory itself so setup-server.sh + nginx.conf live with the app.
cp -R deploy "$STAGE_DIR/deploy"

echo "==> Ensuring remote dir exists: ${REMOTE_DIR}"
ssh_run "mkdir -p '${REMOTE_DIR}' && mkdir -p /var/log/pm2"

echo "==> Rsyncing build to ${SSH_HOST}:${REMOTE_DIR}"
# --delete keeps the remote in sync with what we built; protect logs/.env.
rsync -az --delete \
  --exclude='.env*' \
  --exclude='node_modules/.cache' \
  -e "$(rsync_opts)" \
  "$STAGE_DIR/" "$SSH_HOST:${REMOTE_DIR}/"

ssh_run "chmod +x '${REMOTE_DIR}/deploy/setup-server.sh' '${REMOTE_DIR}/deploy/deploy.sh'"

if [ "$RUN_SETUP" -eq 1 ]; then
  echo "==> Running setup-server.sh on the droplet"
  ssh_run "bash '${REMOTE_DIR}/deploy/setup-server.sh'"
else
  echo "==> Reloading PM2 app"
  ssh_run "
    if pm2 describe ${APP_NAME} >/dev/null 2>&1; then
      pm2 reload ${APP_NAME} --update-env
    else
      pm2 start '${REMOTE_DIR}/deploy/ecosystem.config.js'
    fi
    pm2 save
  "
fi

echo
echo "==> Deploy complete."
echo "    Local check:  curl -sI http://127.0.0.1:3010 (on the box)"
echo "    Public check: curl -sI https://cronwatch.xyz"
