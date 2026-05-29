// PM2 ecosystem for the Cronwatch landing page.
// Runs the Next.js standalone server on port 3010.
// Install: `pm2 start ecosystem.config.js && pm2 save`.

module.exports = {
  apps: [
    {
      name: "cronwatch-web",
      cwd: "/opt/cronwatch-web",
      script: "server.js",
      instances: 1,
      exec_mode: "fork",
      env: {
        NODE_ENV: "production",
        HOSTNAME: "0.0.0.0",
        PORT: "3010",
      },
      max_memory_restart: "300M",
      out_file: "/var/log/pm2/cronwatch-web.out.log",
      error_file: "/var/log/pm2/cronwatch-web.err.log",
      time: true,
    },
  ],
};
