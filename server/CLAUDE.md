# Cronwatch server

## ALWAYS redeploy after changing server code

This server runs on a DigitalOcean droplet behind nginx (`api.cronwatch.xyz`),
**not** locally. Editing files here changes nothing in production until you deploy.

After making any change under `server/`, you MUST redeploy:

```bash
cd server
npm run build      # verify it compiles locally first
./deploy.sh        # rsync + remote build + pm2 reload
```

Then confirm the deploy is live:

```bash
curl -s https://api.cronwatch.xyz/health   # expect {"ok":true}
```

Notes:
- `./deploy.sh --setup` is first-time droplet bootstrap only.
- Secrets live in `$REMOTE_PATH/.env` on the droplet and are never touched by the
  deploy script. Deploy config is in `server/.deploy.env`.
- The plain-HTTP IP serves an nginx 404 for `/health`; always health-check via
  `https://api.cronwatch.xyz`.
