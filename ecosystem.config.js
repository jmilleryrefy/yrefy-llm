// PM2 Configuration for LLM accessible to NPM Docker container
module.exports = {
  apps: [
    {
      name: 'yrefy-llm-backend',
      script: 'app.py',
      interpreter: '/home/yrefy-it/yrefy-llm/backend/venv/bin/python',
      cwd: '/home/yrefy-it/yrefy-llm/backend',
      instances: 1,
      exec_mode: 'fork',
      env: {
        PORT: 8081,
        HOST: '0.0.0.0',  // Bind to all interfaces for NPM access
        FLASK_ENV: 'production',
        PYTHONPATH: './backend'
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
      args: 'run start -- --hostname 0.0.0.0 --port 3005',  // Bind to all interfaces
      cwd: '/home/yrefy-it/yrefy-llm/frontend',
      env: {
        PORT: 3005,
        NODE_ENV: 'production',
        HOSTNAME: '0.0.0.0'  // Bind to all interfaces for NPM access
      },
      error_file: '/home/yrefy-it/yrefy-llm/data/logs/frontend-error.log',
      out_file: '/home/yrefy-it/yrefy-llm/data/logs/frontend-out.log',
      time: true,
      autorestart: true,
      max_memory_restart: '512M'
    }
  ]
};
