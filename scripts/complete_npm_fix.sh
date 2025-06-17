#!/bin/bash
# Complete fix for NPM connectivity to LLM services

echo "🔧 Complete NPM Connectivity Fix"
echo "================================="
echo ""

cd /home/yrefy-it/yrefy-llm

echo "1. 📝 Updating ecosystem.config.js to bind to 0.0.0.0..."

# Backup current config
cp ecosystem.config.js ecosystem.config.js.backup.$(date +%Y%m%d_%H%M%S)

# Update ecosystem.config.js to properly bind to 0.0.0.0
cat > ecosystem.config.js << 'EOF'
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
      args: 'run start -- --hostname 0.0.0.0 --port 3002',  // Bind to all interfaces
      cwd: '/home/yrefy-it/yrefy-llm/frontend',
      env: {
        PORT: 3002,
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
EOF

echo "   ✅ ecosystem.config.js updated"

echo ""
echo "2. 🔄 Restarting PM2 services with new configuration..."

# Stop and start services to ensure clean restart
pm2 stop yrefy-llm-backend yrefy-llm-frontend
pm2 delete yrefy-llm-backend yrefy-llm-frontend 2>/dev/null || true

# Start with new configuration
pm2 start ecosystem.config.js

echo "   ✅ Services restarted"

echo ""
echo "3. ⏳ Waiting for services to fully start..."
sleep 8

echo ""
echo "4. 🧪 Testing service binding..."

# Check what ports are actually listening
echo "Current port bindings:"
echo "   Port 8081: $(ss -tlnp | grep :8081 | awk '{print $4}' || echo 'Not listening')"
echo "   Port 3002: $(ss -tlnp | grep :3002 | awk '{print $4}' || echo 'Not listening')"

echo ""
echo "5. 🌐 Testing connectivity from host..."

# Test from host first
echo "From host machine:"
echo -n "   Backend health: "
if curl -s --connect-timeout 5 http://192.168.128.82:8081/health >/dev/null; then
    echo "✅ Accessible"
    HOST_BACKEND_OK=true
else
    echo "❌ Not accessible"
    HOST_BACKEND_OK=false
fi

echo -n "   Frontend: "
if curl -s --connect-timeout 5 http://192.168.128.82:3002 >/dev/null; then
    echo "✅ Accessible"
    HOST_FRONTEND_OK=true
else
    echo "❌ Not accessible"
    HOST_FRONTEND_OK=false
fi

echo ""
echo "6. 🐳 Testing connectivity from NPM container..."

CONTAINER_NAME="nginx-proxy-manager_nginx-proxy-manager_1"

# Test connectivity from NPM container
echo "From NPM container:"

# Test with host IP
echo -n "   192.168.128.82:8081: "
if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 5 http://192.168.128.82:8081/health >/dev/null 2>&1; then
    echo "✅ Accessible"
    NPM_BACKEND_OK=true
else
    echo "❌ Not accessible"
    NPM_BACKEND_OK=false
fi

echo -n "   192.168.128.82:3002: "
if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 5 http://192.168.128.82:3002 >/dev/null 2>&1; then
    echo "✅ Accessible"
    NPM_FRONTEND_OK=true
else
    echo "❌ Not accessible"
    NPM_FRONTEND_OK=false
fi

echo ""

# Determine next steps based on test results
if [ "$NPM_BACKEND_OK" = true ] && [ "$NPM_FRONTEND_OK" = true ]; then
    echo "🎉 SUCCESS! NPM container can reach LLM services!"
    echo ""
    echo "✅ Ready for NPM configuration:"
    echo "   Domain: chat.it.yrefy"
    echo "   Forward to: 192.168.128.82:3002"
    echo "   SSL: Use existing it.yrefy certificate"
    echo ""
    echo "🌐 NPM Web Interface: http://192.168.128.82:81"
    
elif [ "$HOST_BACKEND_OK" = true ] && [ "$HOST_FRONTEND_OK" = true ]; then
    echo "⚠️  Services accessible from host but NOT from NPM container"
    echo ""
    echo "🔧 Additional troubleshooting needed:"
    
    # Check if UFW is blocking
    echo ""
    echo "7. 🛡️  Checking firewall (UFW)..."
    if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
        echo "   UFW is active - this might be blocking Docker container access"
        echo ""
        echo "   🔧 Option 1: Allow Docker subnet access"
        echo "   sudo ufw allow from 172.0.0.0/8 to any port 8081"
        echo "   sudo ufw allow from 172.0.0.0/8 to any port 3002"
        echo ""
        echo "   🔧 Option 2: Add NPM container to host network"
        echo "   (Requires docker-compose.yml modification)"
    else
        echo "   UFW not active or not found"
    fi
    
    # Check Docker network details
    echo ""
    echo "8. 🌉 Docker network analysis..."
    echo "   NPM container network:"
    docker inspect "$CONTAINER_NAME" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{"\n"}}{{end}}'
    
    echo ""
    echo "   Available networks:"
    docker network ls
    
    echo ""
    echo "🎯 Try these solutions:"
    echo ""
    echo "Option A: Fix firewall (if UFW active)"
    echo "   sudo ufw allow from 172.0.0.0/8 to any port 8081"
    echo "   sudo ufw allow from 172.0.0.0/8 to any port 3002"
    echo ""
    echo "Option B: Use host networking for NPM"
    echo "   Edit /home/yrefy-it/nginx-proxy-manager/docker-compose.yml"
    echo "   Add: network_mode: host"
    echo "   Then: docker-compose down && docker-compose up -d"
    
else
    echo "❌ Services not accessible even from host!"
    echo ""
    echo "🔧 Service binding issue. Let's check PM2 logs:"
    pm2 logs yrefy-llm-backend --lines 10
    echo ""
    pm2 logs yrefy-llm-frontend --lines 10
fi

echo ""
echo "📊 Service Status:"
pm2 status | grep yrefy-llm

echo ""
echo "🎯 Next Steps Summary:"
echo "======================"

if [ "$NPM_BACKEND_OK" = true ] && [ "$NPM_FRONTEND_OK" = true ]; then
    echo "✅ READY: Configure chat.it.yrefy in NPM web interface"
    echo "   1. Go to http://192.168.128.82:81"
    echo "   2. Add Proxy Host: chat.it.yrefy → 192.168.128.82:3002"
    echo "   3. Enable SSL with existing it.yrefy certificate"
    echo "   4. Test https://chat.it.yrefy"
else
    echo "🔧 NEEDS FIX: Network connectivity issue"
    echo "   1. Check firewall settings (UFW)"
    echo "   2. Consider using host networking for NPM"
    echo "   3. Or debug Docker network configuration"
fi

echo ""
echo "📝 Save PM2 configuration:"
echo "   pm2 save"

# Save PM2 configuration
pm2 save