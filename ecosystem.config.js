// ecosystem.config.js - From /home/yrefy-it/yrefy-llm
module.exports = {
  apps: [
    {
      name: 'yrefy-llm-backend',
      script: 'app.py',
      interpreter: '/home/yrefy-it/yrefy-llm/backend/venv/bin/python',  // Use venv Python
      cwd: '/home/yrefy-it/yrefy-llm/backend',
      instances: 2,
      exec_mode: 'cluster',
      env: {
        PORT: 8080,
        HOST: '0.0.0.0',  // Bind to all interfaces for Tailscale access
        AZURE_CLIENT_ID: process.env.AZURE_CLIENT_ID || 'your-azure-app-id',
        AZURE_CLIENT_SECRET: process.env.AZURE_CLIENT_SECRET || 'your-azure-app-secret',
        AZURE_TENANT_ID: process.env.AZURE_TENANT_ID || 'your-tenant-id',
        SECRET_KEY: process.env.SECRET_KEY || 'your-secret-key',
        OLLAMA_BASE_URL: 'http://localhost:11434',
        DATABASE_PATH: '/home/yrefy-it/yrefy-llm/data/usage.db',
        TAILSCALE_IP: '100.71.177.68',
        ALLOWED_ORIGINS: 'http://localhost:3000,http://100.71.177.68:3000,https://100.71.177.68:3000',
        REDIRECT_URI: 'http://100.71.177.68:8080/auth/callback'
      },
      error_file: '/home/yrefy-it/yrefy-llm/data/logs/backend-error.log',
      out_file: '/home/yrefy-it/yrefy-llm/data/logs/backend-out.log',
      time: true,
      autorestart: true,
      max_memory_restart: '1G'
    },
    {
      name: 'yrefy-llm-frontend',
      script: 'npm',
      args: 'run start -- --hostname 0.0.0.0 --port 3001',  // Use port 3001
      cwd: '/home/yrefy-it/yrefy-llm/frontend',
      env: {
        PORT: 3001,  // Changed from 3000 to 3001
        NODE_ENV: 'production',
        HOSTNAME: '0.0.0.0'  // Allow external connections
      },
      error_file: '/home/yrefy-it/yrefy-llm/data/logs/frontend-error.log',
      out_file: '/home/yrefy-it/yrefy-llm/data/logs/frontend-out.log',
      time: true,
      autorestart: true,
      max_memory_restart: '512M'
    }
  ]
};