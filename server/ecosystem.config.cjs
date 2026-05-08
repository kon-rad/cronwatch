// PM2 process manifest. Deploy scripts read this with
// `pm2 startOrReload ecosystem.config.cjs --update-env`.
//
// Runtime secrets (AWS / Deepgram / Together / Firebase) come from
// /opt/cronwatch-server/.env on the droplet, which we create once by hand
// and never overwrite from rsync.

module.exports = {
  apps: [
    {
      name: 'cronwatch-server',
      script: 'dist/index.js',
      cwd: '/opt/cronwatch-server',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_memory_restart: '256M',
      env: {
        NODE_ENV: 'production',
        PORT: '8080',
      },
      time: true,
      out_file: '/var/log/cronwatch-server/out.log',
      error_file: '/var/log/cronwatch-server/error.log',
      merge_logs: true,
    },
  ],
};
