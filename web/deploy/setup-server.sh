#!/usr/bin/env bash
# One-time server provisioning for the Cronwatch landing page.
# Idempotent — safe to re-run. Designed for an Ubuntu droplet that already
# hosts api.cronwatch.xyz (so node, pm2, nginx, certbot are present).
#
# Run from your laptop after deploy.sh has copied the build:
#   ssh root@SERVER 'bash /opt/cronwatch-web/deploy/setup-server.sh'
#
# Or run directly on the server:
#   bash /opt/cronwatch-web/deploy/setup-server.sh

set -euo pipefail

APP_NAME="cronwatch-web"
APP_DIR="/opt/${APP_NAME}"
DOMAIN_PRIMARY="cronwatch.xyz"
DOMAIN_WWW="www.cronwatch.xyz"
NGINX_AVAIL="/etc/nginx/sites-available/${APP_NAME}.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/${APP_NAME}.conf"
LOG_DIR="/var/log/pm2"

echo "==> Ensuring required packages are installed"
NEEDED_BINS=(nginx certbot curl rsync node pm2)
MISSING=0
for bin in "${NEEDED_BINS[@]}"; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing: $bin"; MISSING=1; }
done

if [ "$MISSING" -eq 1 ]; then
  # apt-get update can 404 on EOL Ubuntu releases; tolerate it and let the
  # install step fail loudly if a binary truly isn't reachable.
  apt-get update -y || echo "(apt update failed; continuing — will fail loudly if a package is missing)"
  apt-get install -y --no-install-recommends nginx certbot python3-certbot-nginx curl rsync ca-certificates || true

  if ! command -v node >/dev/null 2>&1; then
    echo "==> Installing Node 22 (NodeSource)"
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
  fi

  if ! command -v pm2 >/dev/null 2>&1; then
    echo "==> Installing PM2 globally"
    npm install -g pm2
  fi
else
  echo "   all required tools already present — skipping apt"
fi

mkdir -p "$LOG_DIR"

echo "==> Linking nginx site"
install -m 0644 "${APP_DIR}/deploy/nginx.${APP_NAME}.conf" "$NGINX_AVAIL"
ln -sf "$NGINX_AVAIL" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx

echo "==> Starting / reloading PM2 app"
cd "$APP_DIR"
if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
  pm2 reload "$APP_NAME" --update-env
else
  pm2 start "${APP_DIR}/deploy/ecosystem.config.js"
fi
pm2 save

# Make sure pm2 comes back on reboot. If pm2-startup was already wired by a
# previous app this is a no-op, otherwise it installs the systemd unit.
if ! systemctl list-unit-files | grep -q '^pm2-root\.service'; then
  echo "==> Wiring pm2 systemd startup"
  pm2 startup systemd -u root --hp /root | tail -n 1 | bash || true
  pm2 save
fi

echo
echo "==> Checking DNS for ${DOMAIN_PRIMARY}"
SERVER_IP=$(curl -fsSL https://api.ipify.org || hostname -I | awk '{print $1}')
RESOLVED=$(getent hosts "$DOMAIN_PRIMARY" | awk '{print $1}' | head -1 || true)
echo "   server IP : ${SERVER_IP}"
echo "   resolves  : ${RESOLVED:-<none>}"

if [ "${RESOLVED:-}" = "$SERVER_IP" ]; then
  echo "==> DNS is live — issuing certificate via certbot"
  certbot --nginx \
    --non-interactive --agree-tos --redirect \
    -m "admin@${DOMAIN_PRIMARY}" \
    -d "$DOMAIN_PRIMARY" -d "$DOMAIN_WWW"
  systemctl reload nginx
else
  cat <<EOF

DNS for ${DOMAIN_PRIMARY} does not (yet) point at this server. The site is
serving over plain HTTP for now. Once Namecheap propagates, run:

  certbot --nginx -d ${DOMAIN_PRIMARY} -d ${DOMAIN_WWW}

EOF
fi

echo
echo "==> Done. PM2 status:"
pm2 list
