# cronwatch-server

Capture proxy for the Cronwatch mobile app. One endpoint:

```
POST /capture                 (multipart/form-data, Bearer Firebase ID token)
  audio: <file>               (m4a / wav / mp3 / webm / ogg)
  now:   <ISO timestamp>      (optional; defaults to server time)
```

Response:

```json
{
  "transcript": "deep work on the auth refactor from 9 to 10:30",
  "audioKey":   "captures/<uid>/2026-05-07/<uuid>.m4a",
  "audioUrl":   "https://<bucket>.s3.<region>.amazonaws.com/<key>",
  "draft": {
    "category":  "deep",
    "note":      "Auth refactor",
    "startTime": "2026-05-07T09:00:00.000Z",
    "endTime":   "2026-05-07T10:30:00.000Z"
  }
}
```

The proxy:

1. Verifies the Firebase ID token (`firebase-admin`).
2. Uploads the raw audio to S3 *and* sends it to Deepgram in parallel.
3. Sends the transcript to Together AI with a strict system prompt; parses + validates the JSON.

Secrets never leave the server — the mobile app only knows the proxy URL.

---

## Local development

```sh
cp .env.example .env
# fill in AWS, Deepgram, Together, Firebase secrets
npm install
npm run dev    # tsx watch on :8080
```

Smoke test:

```sh
curl -F "audio=@sample.m4a" \
     -H "Authorization: Bearer <firebase-id-token>" \
     http://localhost:8080/capture
```

`GET /health` → `{ "ok": true }` (no auth).

---

## Deploy to a DigitalOcean droplet (PM2 + nginx)

The deployment is fully scripted. From your laptop:

```sh
cd server
cp .deploy.env.example .deploy.env
# edit .deploy.env: set DROPLET_HOST to the droplet IP
./deploy.sh --setup        # one-time: installs Node 20, pm2, nginx, ufw rules
ssh root@<droplet> 'cp /opt/cronwatch-server/.env.example /opt/cronwatch-server/.env && nano /opt/cronwatch-server/.env'
./deploy.sh                # rsync code, build, pm2 reload
curl http://<droplet>/health
```

What lives where:

| File | Where it runs | Purpose |
| --- | --- | --- |
| `deploy.sh` | your laptop | rsync push + `ssh` orchestration |
| `scripts/setup-server.sh` | droplet (once) | installs Node, pm2, nginx, opens ufw |
| `scripts/remote-deploy.sh` | droplet (every deploy) | `npm install` + `npm run build` + `pm2 startOrReload` |
| `ecosystem.config.cjs` | droplet | pm2 process definition (cwd, log paths, env) |
| `nginx/cronwatch.conf` | droplet | reverse-proxy `:80` → `127.0.0.1:8080`, 30 MB body limit, 120 s timeouts |
| `.deploy.env` | your laptop only | droplet IP / ssh user (gitignored) |
| `/opt/cronwatch-server/.env` | droplet only | runtime secrets (NOT touched by rsync) |

The deploy script refuses to run if `/opt/cronwatch-server/.env` is missing on
the droplet — that prevents a confusing pm2 crash loop on first deploy.

### Adding TLS later

When you're ready for a real domain:

```sh
apt install certbot python3-certbot-nginx
certbot --nginx -d api.your-domain.com
```

certbot will rewrite `nginx/cronwatch.conf` in-place to add `listen 443 ssl`
and the cert paths.

### Alternative: DigitalOcean App Platform

If you'd rather not manage a droplet, the included `Dockerfile` + `.do/app.yaml`
work with App Platform. Push this folder to a git repo, create an app from
it, and add the same secrets via the App Platform env panel.

---

## AWS S3 setup

The server uploads with `PutObject`. The IAM user needs at minimum:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject"],
    "Resource": "arn:aws:s3:::<your-bucket>/*"
  }]
}
```

Bucket can be private; the client never reads back the audio in the current
flow — `audioUrl` is stored on the entry as a reference. If you later want
playback in-app, switch to presigned GETs.
