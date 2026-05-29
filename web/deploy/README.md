# Cronwatch landing — deployment

Self-hosted on the same DigitalOcean droplet as `api.cronwatch.xyz` (the capture proxy). The landing page runs as the **`cronwatch-web`** PM2 app on port `3010`, fronted by nginx with a Let's Encrypt cert for `cronwatch.xyz` + `www.cronwatch.xyz`.

| | |
|--|--|
| Server | `root@147.182.202.63` (DigitalOcean droplet) |
| App dir | `/opt/cronwatch-web` |
| Port | `3010` (loopback only) |
| PM2 name | `cronwatch-web` |
| nginx site | `/etc/nginx/sites-available/cronwatch-web.conf` |
| Domain | `cronwatch.xyz`, `www.cronwatch.xyz` |
| Logs | `/var/log/pm2/cronwatch-web.{out,err}.log`, `pm2 logs cronwatch-web` |

The api side (`api.cronwatch.xyz`, port 8080, `/opt/cronwatch-server`) is untouched by these scripts.

---

## 1. Point the domain at the droplet (Namecheap)

Do this **before** running setup so certbot can issue a cert in the same step.

1. Sign in to Namecheap → **Domain List** → `cronwatch.xyz` → **Manage**.
2. Open the **Advanced DNS** tab.
3. If a default `URL Redirect Record` for `@` exists, **delete it** — it conflicts with an A record.
4. Add two records:

   | Type        | Host  | Value             | TTL       |
   |-------------|-------|-------------------|-----------|
   | `A Record`  | `@`   | `147.182.202.63`  | Automatic |
   | `CNAME`     | `www` | `cronwatch.xyz.`  | Automatic |

   The trailing dot on `cronwatch.xyz.` is required for CNAME values.

5. The `api` subdomain already has its own A record (it's serving today). Leave it alone.
6. Click the green checkmark to save.

Verify propagation from your laptop (usually 5–30 min):

```bash
dig +short cronwatch.xyz
dig +short www.cronwatch.xyz
# both should print 147.182.202.63 (www may print cronwatch.xyz then the IP)
```

Until DNS resolves to the droplet, certbot will refuse to issue a cert and the `setup-server.sh` script will fall back to plain HTTP and tell you to re-run certbot later.

## 2. First deploy

From the repo root (or anywhere — the script self-locates):

```bash
./web/deploy/deploy.sh --setup
```

What this does:

1. `npm ci` + `npm run build` locally (Next.js standalone output).
2. Rsyncs `.next/standalone/`, `.next/static/`, `public/`, and `deploy/` into `/opt/cronwatch-web` on the droplet.
3. Runs `setup-server.sh` on the droplet, which:
   - Ensures nginx, certbot, node, pm2 are installed (no-op since the api already needs them).
   - Symlinks `nginx.cronwatch-web.conf` into `sites-enabled/` and reloads nginx.
   - Starts (or reloads) the `cronwatch-web` PM2 app.
   - Saves the PM2 process list so it survives reboots.
   - If DNS resolves to this server, runs `certbot --nginx -d cronwatch.xyz -d www.cronwatch.xyz` to add SSL + the HTTP→HTTPS redirect.

Smoke test:

```bash
curl -sI https://cronwatch.xyz | head -3
ssh root@147.182.202.63 'pm2 list | grep cronwatch'
```

## 3. Subsequent deploys

```bash
./web/deploy/deploy.sh
```

This skips the setup step — it just rebuilds, rsyncs, and reloads PM2 (zero-downtime; PM2 keeps the old process up while the new one boots). Use `--setup` again only if you change `nginx.cronwatch-web.conf`, `ecosystem.config.js`, or want to re-run `certbot`.

`./web/deploy/deploy.sh --skip-build` ships the existing local `.next/standalone` without rebuilding (handy if CI or another machine produced the build).

## 4. Files

| File | Where it ends up | Purpose |
|------|------------------|---------|
| `deploy.sh` | runs on your laptop | Build → rsync → reload |
| `setup-server.sh` | runs on the droplet | Idempotent provisioning + cert issue |
| `nginx.cronwatch-web.conf` | `/etc/nginx/sites-available/cronwatch-web.conf` | nginx server block (port 80 → 3010, certbot rewrites in place when SSL is added) |
| `ecosystem.config.js` | `/opt/cronwatch-web/deploy/ecosystem.config.js` | PM2 config: `node server.js` on port 3010 |

The Next.js standalone build packs an internal `server.js` next to a minimal `node_modules`. PM2 runs it directly — there is no `npm start` on the server.

## 5. Troubleshooting

**`pm2 describe cronwatch-web` says it's not started.** The standalone build needs the static assets next to it. Confirm `/opt/cronwatch-web/.next/static/` exists (deploy.sh copies it in). If missing, re-run the deploy.

**`502 Bad Gateway` from cronwatch.xyz.** PM2 process is down. `pm2 logs cronwatch-web --lines 50` will show why. Common cause: port 3010 already taken — `ss -tlnp | grep 3010` to confirm.

**Certbot says "DNS problem".** DNS hasn't propagated yet. Wait, then re-run `certbot --nginx -d cronwatch.xyz -d www.cronwatch.xyz` on the box.

**Need to roll back.** Each deploy overwrites the previous build. Either redeploy from a prior git commit, or `pm2 stop cronwatch-web` to take it offline (nginx will return 502 until you bring it back).
