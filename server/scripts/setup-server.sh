#!/usr/bin/env bash
#
# One-time droplet bootstrap for the Cronwatch capture proxy.
#
# Run from `deploy.sh --setup` (which uploads the repo and execs this).
# Idempotent: re-running won't break anything.
#
# Installs:
#   - Node.js 20 (NodeSource)
#   - pm2 (global)
#   - nginx (with our reverse-proxy site)
#   - ufw rules for 22 + 80
#
# Does NOT create /opt/cronwatch-server/.env. You create that by hand
# after this script finishes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_SITE="$REPO_ROOT/nginx/cronwatch.conf"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root (or via 'deploy.sh --setup' from your laptop)." >&2
  exit 1
fi

bold "▶︎ apt update + base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates rsync ufw nginx

if ! command -v node >/dev/null 2>&1 || [[ "$(node -v 2>/dev/null | cut -dv -f2 | cut -d. -f1)" -lt 20 ]]; then
  bold "▶︎ Installing Node.js 20 from NodeSource"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

if ! command -v pm2 >/dev/null 2>&1; then
  bold "▶︎ Installing pm2 globally"
  npm install -g pm2
fi

bold "▶︎ Configuring pm2 to start on boot"
# 'pm2 startup' prints a sudo command to copy/paste; running it via systemd
# directly is simpler and idempotent.
env PATH="$PATH:/usr/bin" pm2 startup systemd -u root --hp /root >/dev/null

bold "▶︎ Installing nginx site config"
install -m 0644 "$NGINX_SITE" /etc/nginx/sites-available/cronwatch.conf
ln -sf /etc/nginx/sites-available/cronwatch.conf /etc/nginx/sites-enabled/cronwatch.conf
# Disable the default 'Welcome to nginx' site so ours is the default_server.
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
systemctl enable nginx

bold "▶︎ Configuring ufw (allow ssh + http)"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
# Ensure ufw is enabled but don't lock ourselves out if it was already off.
if ! ufw status | grep -q "Status: active"; then
  yes | ufw enable >/dev/null
fi

bold "▶︎ Preparing log directory"
mkdir -p /var/log/cronwatch-server
chown root:root /var/log/cronwatch-server

green "✓ Droplet is ready. Now create /opt/cronwatch-server/.env with your secrets and run ./deploy.sh from your laptop."
