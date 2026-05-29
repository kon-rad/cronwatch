#!/usr/bin/env bash
#
# Deploy the cronwatch capture proxy to a DigitalOcean droplet.
#
# Run from your laptop, in the `server/` directory. Requires:
#   - a working ssh key for the droplet
#   - rsync installed locally (default on macOS / most Linux)
#   - .deploy.env filled in (copy .deploy.env.example)
#
# Usage:
#   ./deploy.sh                # rsync + remote build + pm2 reload
#   ./deploy.sh --setup        # first-time droplet bootstrap (Node, pm2, nginx)
#
# The actual app secrets (Deepgram, Together, Firebase) live in
# $REMOTE_PATH/.env on the server. They are NOT touched by this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---- config ---------------------------------------------------------------

if [[ -f .deploy.env ]]; then
  # shellcheck disable=SC1091
  source .deploy.env
else
  echo "❌  .deploy.env not found. Copy .deploy.env.example to .deploy.env and fill it in." >&2
  exit 1
fi

: "${DROPLET_HOST:?DROPLET_HOST is required in .deploy.env}"
: "${SSH_USER:=root}"
: "${SSH_PORT:=22}"
: "${REMOTE_PATH:=/opt/cronwatch-server}"
: "${SERVICE_NAME:=cronwatch-server}"
SSH_KEY="${SSH_KEY:-}"

SSH_OPTS=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY")
fi

ssh_run() {
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$DROPLET_HOST" "$@"
}

rsh_cmd() {
  local rsh="ssh -p $SSH_PORT -o StrictHostKeyChecking=accept-new"
  if [[ -n "$SSH_KEY" ]]; then
    rsh="$rsh -i $SSH_KEY"
  fi
  printf '%s' "$rsh"
}

rsync_push() {
  rsync -az --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'dist' \
    --exclude '.env' \
    --exclude '.env.local' \
    --exclude '.deploy.env' \
    --exclude '*.log' \
    --exclude '.DS_Store' \
    -e "$(rsh_cmd)" \
    ./ "$SSH_USER@$DROPLET_HOST:$REMOTE_PATH/"
}

# together.ts reads join(__dirname, '../../shared/categories.json'). In the
# compiled dist at $REMOTE_PATH/dist, that resolves to $(dirname REMOTE_PATH)/shared.
# Ship the repo-root shared/ to that sibling location so prod can find it.
rsync_shared() {
  local shared_local="$SCRIPT_DIR/../shared"
  local shared_remote
  shared_remote="$(dirname "$REMOTE_PATH")/shared"
  if [[ ! -d "$shared_local" ]]; then
    return 0
  fi
  ssh_run "mkdir -p '$shared_remote'"
  rsync -az --delete \
    --exclude '.DS_Store' \
    -e "$(rsh_cmd)" \
    "$shared_local/" "$SSH_USER@$DROPLET_HOST:$shared_remote/"
}

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

# ---- modes ----------------------------------------------------------------

if [[ "${1:-}" == "--setup" ]]; then
  bold "▶︎ One-time droplet bootstrap on $SSH_USER@$DROPLET_HOST"
  bold "  Creating $REMOTE_PATH and pushing code…"
  ssh_run "mkdir -p $REMOTE_PATH /var/log/cronwatch-server"
  rsync_push
  rsync_shared
  bold "  Running setup-server.sh on the droplet…"
  ssh_run "bash $REMOTE_PATH/scripts/setup-server.sh"
  green "✓ Bootstrap complete."
  cat <<EOF

Next steps:
  1. SSH in and create $REMOTE_PATH/.env from .env.example with your secrets:
       ssh $SSH_USER@$DROPLET_HOST
       cd $REMOTE_PATH
       cp .env.example .env
       \$EDITOR .env

  2. Run the regular deploy:
       ./deploy.sh

  3. Health check:
       curl http://$DROPLET_HOST/health

EOF
  exit 0
fi

bold "▶︎ Deploying to $SSH_USER@$DROPLET_HOST:$REMOTE_PATH"

# Refuse to deploy if .env doesn't exist on the server. Saves a confusing
# crash loop where pm2 keeps restarting because env vars are missing.
if ! ssh_run "test -f $REMOTE_PATH/.env"; then
  red "✗ $REMOTE_PATH/.env not found on droplet."
  red "  Run './deploy.sh --setup' first, then create the .env on the server."
  exit 1
fi

bold "  Syncing code…"
rsync_push

bold "  Syncing shared/ → $(dirname "$REMOTE_PATH")/shared…"
rsync_shared

bold "  Running remote-deploy.sh…"
ssh_run "bash $REMOTE_PATH/scripts/remote-deploy.sh '$SERVICE_NAME'"

bold "  PM2 status:"
ssh_run "pm2 list"

green "✓ Deployed. Health check:"
echo "  curl http://$DROPLET_HOST/health"
