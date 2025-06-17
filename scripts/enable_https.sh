#!/bin/bash
# Setup HTTPS for LLM system with self-signed certificates

echo "🔒 Setting up HTTPS for Tailscale access..."

cd /home/yrefy-it/yrefy-llm

# Create SSL directory
mkdir -p ssl

# Generate self-signed certificate for Tailscale IP
echo "1. Generating SSL certificate for 100.71.177.68..."
openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
  -subj "/C=US/ST=CA/L=SF/O=YrefyLLM/CN=100.71.177.68" \
  -addext "subjectAltName=IP:100.71.177.68,IP:127.0.0.1,DNS:localhost"

chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem

echo "   ✅ SSL certificate generated"

# Update backend configuration
echo "2. Updating backend configuration for HTTPS..."
cd backend

# Update ALLOWED_ORIGINS for HTTPS
if grep -q "ALLOWED_ORIGINS=" .env; then
    sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://localhost:3002,https://100.71.177.68:3002,http://localhost:3002|" .env
else
    echo "ALLOWED_ORIGINS=https://localhost:3002,https://100.71.177.68:3002,http://localhost:3002" >> .env
fi

# Update REDIRECT_URI for HTTPS
if grep -q "REDIRECT_URI=" .env; then
    sed -i "s|REDIRECT_URI=.*|REDIRECT_URI=https://100.71.177.68:3002/auth/callback|" .env
else
    echo "REDIRECT_URI=https://100.71.177.68:3002/auth/callback" >> .env
fi

echo "   ✅ Backend configuration updated"

# Update frontend for HTTPS
echo "3. Setting up HTTPS server for Next.js..."
cd ../frontend

# Create HTTPS server file
cat > server.js << 'EOF2'
const { createServer } = require('https');
const { parse } = require('url');
const next = require('next');
const fs = require('fs');
const path = require('path');

const dev = process.env.NODE_ENV !== 'production';
const hostname = '0.0.0.0';
const port = parseInt(process.env.PORT, 10) || 3002;

const app = next({ dev, hostname, port });
const handle = app.getRequestHandler();

// SSL certificate paths
const sslPath = path.join(__dirname, '..', 'ssl');
const httpsOptions = {
  key: fs.readFileSync(path.join(sslPath, 'key.pem')),
  cert: fs.readFileSync(path.join(sslPath, 'cert.pem')),
};

app.prepare().then(() => {
  createServer(httpsOptions, async (req, res) => {
    try {
      const parsedUrl = parse(req.url, true);
      await handle(req, res, parsedUrl);
    } catch (err) {
      console.error('Error occurred handling', req.url, err);
      res.statusCode = 500;
      res.end('internal server error');
    }
  })
  .listen(port, hostname, (err) => {
    if (err) throw err;
    console.log(`> Ready on https://${hostname}:${port}`);
  });
});
EOF2

# Update package.json for HTTPS
npm pkg set scripts.https="node server.js"
npm pkg set scripts.start:https="NODE_ENV=production node server.js"

# Update .env.local for HTTPS
if grep -q "NEXT_PUBLIC_API_BASE_URL=" .env.local; then
    sed -i "s|NEXT_PUBLIC_API_BASE_URL=.*|NEXT_PUBLIC_API_BASE_URL=http://100.71.177.68:8081|" .env.local
else
    echo "NEXT_PUBLIC_API_BASE_URL=http://100.71.177.68:8081" >> .env.local
fi

if grep -q "NEXTAUTH_URL=" .env.local; then
    sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=https://100.71.177.68:3002|" .env.local
else
    echo "NEXTAUTH_URL=https://100.71.177.68:3002" >> .env.local
fi

# Add HTTPS flag
echo "HTTPS=true" >> .env.local

echo "   ✅ HTTPS server configured"

# Update ecosystem.config.js for HTTPS
echo "4. Updating PM2 configuration..."
cd ..

# Update PM2 config to use HTTPS server
sed -i 's|args: '\''npm run start|args: '\''npm run https|' ecosystem.config.js

# Also update the env section to include HTTPS
sed -i '/PORT: 3002/a\        HTTPS: true,' ecosystem.config.js

echo "   ✅ PM2 configuration updated"

# Build frontend if needed
echo "5. Building frontend..."
cd frontend
if [ ! -d ".next" ]; then
    npm run build
fi
cd ..

# Restart services
echo "6. Restarting services with HTTPS..."
pm2 restart yrefy-llm-frontend

echo "7. Waiting for HTTPS service to start..."
sleep 8

# Test HTTPS access
echo "8. Testing HTTPS access..."
if curl -k -s https://100.71.177.68:3002 > /dev/null; then
    echo "   ✅ HTTPS frontend accessible"
    echo "   Status: $(curl -k -s -o /dev/null -w "%{http_code}" https://100.71.177.68:3002)"
else
    echo "   ❌ HTTPS frontend not accessible"
    echo "   Checking PM2 logs..."
    pm2 logs yrefy-llm-frontend --lines 5
fi

# Test backend (still HTTP)
if curl -s http://100.71.177.68:8081/health > /dev/null; then
    echo "   ✅ Backend still accessible via HTTP"
else
    echo "   ❌ Backend connection issue"
fi

echo ""
echo "🎯 HTTPS Configuration Complete!"
echo "================================="
echo ""
echo "🌐 New Secure Access URLs:"
echo "   Frontend:  https://100.71.177.68:3002  (HTTPS - Secure!)"
echo "   Backend:   http://100.71.177.68:8081   (HTTP - Internal API)"
echo ""
echo "🔐 Azure AD Configuration Required:"
echo "   1. Go to Azure Portal → App registrations → Your LLM app"
echo "   2. Authentication → Platform configurations → Web"
echo "   3. Add this redirect URI:"
echo "      https://100.71.177.68:3002/auth/callback"
echo "   4. Save the configuration"
echo ""
echo "⚠️  Browser Security Notice:"
echo "   • You'll see a certificate warning (this is normal)"
echo "   • Click 'Advanced' → 'Proceed to 100.71.177.68 (unsafe)'"
echo "   • The connection is encrypted, just not verified by a CA"
echo ""
echo "📊 Monitoring:"
echo "   pm2 logs yrefy-llm-frontend  # View HTTPS server logs"
echo "   pm2 status                   # Check service status"
echo ""
echo "✅ Ready for secure Tailscale access!"
echo "🚀 Navigate to: https://100.71.177.68:3002"
