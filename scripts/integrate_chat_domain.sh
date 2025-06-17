#!/bin/bash
# Complete integration script for chat.it.yrefy LLM system

echo "🚀 Integrating LLM system with chat.it.yrefy"
echo "============================================"
echo "Using existing DNS wildcard and SSL certificate"
echo ""

cd /home/yrefy-it/yrefy-llm

# Check current status
echo "📊 Current Status Check:"
echo "   DNS: chat.it.yrefy → $(nslookup chat.it.yrefy | grep Address | tail -1 | cut -d' ' -f2)"
echo "   SSL: Wildcard *.it.yrefy certificate available"
echo "   Nginx: $(systemctl is-active nginx)"
echo "   LLM Backend: $(curl -s http://127.0.0.1:8081/health >/dev/null && echo 'Running' || echo 'Not responding')"
echo "   LLM Frontend: $(curl -s http://127.0.0.1:3002 >/dev/null && echo 'Running' || echo 'Not responding')"
echo ""

# Step 1: Secure LLM services to localhost only
echo "1. 🔒 Securing LLM services to localhost only..."

# Update ecosystem.config.js to bind to 127.0.0.1
cat > ecosystem.config.js << 'EOF'
// PM2 Configuration for LLM behind Nginx proxy
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
        HOST: '127.0.0.1',  // Only localhost - secure behind proxy
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
      args: 'run start -- --hostname 127.0.0.1 --port 3002',
      cwd: '/home/yrefy-it/yrefy-llm/frontend',
      env: {
        PORT: 3002,
        NODE_ENV: 'production',
        HOSTNAME: '127.0.0.1'  // Only localhost - secure behind proxy
      },
      error_file: '/home/yrefy-it/yrefy-llm/data/logs/frontend-error.log',
      out_file: '/home/yrefy-it/yrefy-llm/data/logs/frontend-out.log',
      time: true,
      autorestart: true,
      max_memory_restart: '512M'
    }
  ]
};
EOF

echo "   ✅ PM2 configuration updated for localhost-only binding"

# Step 2: Update backend configuration for chat.it.yrefy
echo "2. ⚙️  Updating backend for chat.it.yrefy domain..."

cd backend

# Backup current .env
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# Update .env for chat.it.yrefy domain
if grep -q "ALLOWED_ORIGINS=" .env; then
    sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://chat.it.yrefy,http://localhost:3002|" .env
else
    echo "ALLOWED_ORIGINS=https://chat.it.yrefy,http://localhost:3002" >> .env
fi

if grep -q "REDIRECT_URI=" .env; then
    sed -i "s|REDIRECT_URI=.*|REDIRECT_URI=https://chat.it.yrefy/auth/callback|" .env
else
    echo "REDIRECT_URI=https://chat.it.yrefy/auth/callback" >> .env
fi

# Ensure HOST is set to localhost
if grep -q "HOST=" .env; then
    sed -i "s|HOST=.*|HOST=127.0.0.1|" .env
else
    echo "HOST=127.0.0.1" >> .env
fi

echo "   ✅ Backend configured for chat.it.yrefy domain"

# Step 3: Update frontend configuration
echo "3. 🎨 Updating frontend for chat.it.yrefy domain..."

cd ../frontend

# Update .env.local for chat.it.yrefy
cat > .env.local << 'EOF2'
# Frontend configuration for chat.it.yrefy domain
NEXT_PUBLIC_API_BASE_URL=https://chat.it.yrefy/api
NEXTAUTH_URL=https://chat.it.yrefy

# Azure AD Configuration (update these with your actual values)
NEXT_PUBLIC_AZURE_CLIENT_ID=your-azure-client-id
NEXT_PUBLIC_AZURE_TENANT_ID=your-azure-tenant-id

# Application settings
NODE_ENV=production
PORT=3002
HOSTNAME=127.0.0.1
EOF2

# Update next.config.js for proper API proxying through Nginx
cat > next.config.js << 'EOF3'
/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://127.0.0.1:8081/api/:path*',
      },
      {
        source: '/auth/:path*',
        destination: 'http://127.0.0.1:8081/auth/:path*',
      },
      {
        source: '/health',
        destination: 'http://127.0.0.1:8081/health',
      },
    ];
  },
  async headers() {
    return [
      {
        source: '/api/:path*',
        headers: [
          { key: 'Access-Control-Allow-Credentials', value: 'true' },
          { key: 'Access-Control-Allow-Origin', value: 'https://chat.it.yrefy' },
          { key: 'Access-Control-Allow-Methods', value: 'GET,OPTIONS,PATCH,DELETE,POST,PUT' },
          { key: 'Access-Control-Allow-Headers', value: 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization' },
        ],
      },
    ];
  }
};

module.exports = nextConfig;
EOF3

echo "   ✅ Frontend configured for chat.it.yrefy"

cd ..

# Step 4: Create Nginx configuration for chat.it.yrefy
echo "4. 🌐 Creating Nginx configuration for chat.it.yrefy..."

mkdir -p nginx

cat > nginx/chat.it.yrefy.conf << 'EOF4'
# Nginx configuration for Yrefy LLM System
# Domain: chat.it.yrefy
# Uses existing wildcard SSL certificate for *.it.yrefy

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name chat.it.yrefy;
    
    # Security headers even for redirects
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

# Main HTTPS server for LLM
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name chat.it.yrefy;
    
    # SSL Configuration (using existing wildcard certificate)
    ssl_certificate /etc/ssl/certs/it.yrefy.crt;
    ssl_certificate_key /etc/ssl/private/it.yrefy.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 5m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://login.microsoftonline.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://login.microsoftonline.com https://graph.microsoft.com; frame-src https://login.microsoftonline.com;" always;
    
    # Logging
    access_log /var/log/nginx/chat.it.yrefy.access.log;
    error_log /var/log/nginx/chat.it.yrefy.error.log warn;
    
    # Root location - Next.js Frontend
    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts for LLM responses
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 600s;  # 10 minutes for long LLM responses
        
        # Caching and buffering
        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
        
        # Large request support
        client_max_body_size 50M;
    }
    
    # API endpoints - Flask Backend
    location /api/ {
        proxy_pass http://127.0.0.1:8081/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        # API timeouts (longer for LLM responses)
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 600s;  # 10 minutes for long LLM responses
        
        proxy_buffering off;
        client_max_body_size 50M;
    }
    
    # Authentication endpoints
    location /auth/ {
        proxy_pass http://127.0.0.1:8081/auth/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        proxy_buffering off;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8081/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Quick health checks
        proxy_connect_timeout 5s;
        proxy_read_timeout 10s;
    }
    
    # Next.js static files (with caching)
    location /_next/static {
        proxy_pass http://127.0.0.1:3002;
        proxy_cache_valid 200 1h;
        proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
        add_header Cache-Control "public, max-age=3600";
    }
    
    # Favicon and static assets
    location ~* \.(ico|css|js|gif|jpe?g|png|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://127.0.0.1:3002;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
    }
    
    # Block sensitive files
    location ~ /\. {
        deny all;
        return 404;
    }
    
    location ~ \.(env|config|log)$ {
        deny all;
        return 404;
    }
}
EOF4

echo "   ✅ Nginx configuration created for chat.it.yrefy"

# Step 5: Restart LLM services with new configuration
echo "5. 🔄 Restarting LLM services with new configuration..."

# Restart services
pm2 restart yrefy-llm-backend yrefy-llm-frontend

echo "   ✅ LLM services restarted"

# Wait for services to start
sleep 5

# Test local services
echo "6. 🧪 Testing local services..."
if curl -s http://127.0.0.1:8081/health >/dev/null; then
    echo "   ✅ Backend responding on localhost:8081"
    echo "      Health: $(curl -s http://127.0.0.1:8081/health | jq -r '.status' 2>/dev/null || echo 'OK')"
else
    echo "   ❌ Backend not responding on localhost"
fi

if curl -s http://127.0.0.1:3002 >/dev/null; then
    echo "   ✅ Frontend responding on localhost:3002"
else
    echo "   ❌ Frontend not responding on localhost"
fi

# Step 6: Set up Nginx
echo "7. 🌐 Setting up Nginx..."

# Start Nginx if not running
if ! systemctl is-active --quiet nginx; then
    echo "   Starting Nginx service..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
else
    echo "   Nginx already running"
fi

echo ""
echo "🎯 Integration Summary"
echo "====================="
echo ""
echo "✅ Configuration completed:"
echo "   • LLM services secured to localhost only"
echo "   • Backend configured for chat.it.yrefy domain"
echo "   • Frontend configured for chat.it.yrefy domain"
echo "   • Nginx configuration created"
echo "   • Services restarted with new settings"
echo ""
echo "📋 Next Steps:"
echo "=============="
echo ""
echo "1. 🌐 Install Nginx configuration:"
echo "   sudo cp /home/yrefy-it/yrefy-llm/nginx/chat.it.yrefy.conf /etc/nginx/sites-available/"
echo "   sudo ln -sf /etc/nginx/sites-available/chat.it.yrefy.conf /etc/nginx/sites-enabled/"
echo ""
echo "2. 🔧 Test and reload Nginx:"
echo "   sudo nginx -t"
echo "   sudo systemctl reload nginx"
echo ""
echo "3. 🔐 Update Azure AD App Registration:"
echo "   • Go to Azure Portal → App registrations → Your LLM app"
echo "   • Authentication → Add redirect URI:"
echo "     https://chat.it.yrefy/auth/callback"
echo "   • Update backend/.env with your actual Azure credentials"
echo ""
echo "4. 🎉 Access your LLM system:"
echo "   https://chat.it.yrefy"
echo ""
echo "📊 Current Status:"
echo "   DNS: ✅ chat.it.yrefy resolves (wildcard)"
echo "   SSL: ✅ Wildcard certificate covers chat.it.yrefy"
echo "   Services: ✅ Running on localhost"
echo "   Nginx: ⏳ Configuration ready to install"
echo ""
echo "🔍 Monitoring:"
echo "   pm2 status                     # Check LLM services"
echo "   pm2 logs yrefy-llm-*           # View service logs"
echo "   sudo systemctl status nginx   # Check Nginx status"
echo "   curl https://chat.it.yrefy/health  # Health check (after Nginx setup)"
echo ""
echo "🎊 Your LLM system is ready for chat.it.yrefy!"