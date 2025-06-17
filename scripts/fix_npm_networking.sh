#!/bin/bash
# Fix network connectivity between NPM container and host LLM services

echo "🔧 Fixing NPM Network Connectivity for LLM Services"
echo "==================================================="
echo ""

# Get container details
CONTAINER_NAME="nginx-proxy-manager_nginx-proxy-manager_1"

echo "1. 🌐 Testing different host addresses from NPM container..."

# Test various ways to reach host from container
echo "Testing connectivity options:"

# Test host.docker.internal
echo -n "   host.docker.internal:8081 → "
if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 3 http://host.docker.internal:8081/health >/dev/null 2>&1; then
    echo "✅ WORKS"
    HOST_ADDRESS="host.docker.internal"
else
    echo "❌ Failed"
fi

# Test Docker bridge gateway (common default)
echo -n "   172.17.0.1:8081 → "
if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 3 http://172.17.0.1:8081/health >/dev/null 2>&1; then
    echo "✅ WORKS"
    HOST_ADDRESS="172.17.0.1"
else
    echo "❌ Failed"
fi

# Test host IP
echo -n "   192.168.128.82:8081 → "
if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 3 http://192.168.128.82:8081/health >/dev/null 2>&1; then
    echo "✅ WORKS"
    HOST_ADDRESS="192.168.128.82"
else
    echo "❌ Failed"
fi

# Find Docker gateway IP dynamically
GATEWAY_IP=$(docker network inspect nginx-proxy-manager_npm_network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
if [ -n "$GATEWAY_IP" ]; then
    echo -n "   $GATEWAY_IP:8081 → "
    if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 3 http://$GATEWAY_IP:8081/health >/dev/null 2>&1; then
        echo "✅ WORKS"
        HOST_ADDRESS="$GATEWAY_IP"
    else
        echo "❌ Failed"
    fi
fi

# If none work, check if we need to expose services differently
if [ -z "$HOST_ADDRESS" ]; then
    echo ""
    echo "❌ None of the standard methods work. Let's check current service binding..."
    
    echo "2. 📊 Current LLM service binding:"
    echo "   Backend (8081): $(netstat -tlnp | grep :8081 | awk '{print $4}')"
    echo "   Frontend (3002): $(netstat -tlnp | grep :3002 | awk '{print $4}')"
    
    echo ""
    echo "🔧 Option 1: Bind services to all interfaces (0.0.0.0)"
    echo "   This allows Docker containers to reach them"
    
    # Check current PM2 config
    echo ""
    echo "Current PM2 binding in ecosystem.config.js:"
    grep -A 2 -B 2 "HOST\|HOSTNAME" /home/yrefy-it/yrefy-llm/ecosystem.config.js || echo "   No explicit HOST binding found"
    
    echo ""
    echo "🎯 Recommended fix:"
    echo "   1. Update LLM services to bind to 0.0.0.0 (all interfaces)"
    echo "   2. Use Docker's host networking mode (less secure)"
    echo "   3. Or add services to the NPM Docker network"
    
else
    echo ""
    echo "✅ Found working host address: $HOST_ADDRESS"
    echo ""
    echo "2. 🧪 Testing both LLM services..."
    
    # Test backend
    echo -n "   Backend ($HOST_ADDRESS:8081): "
    if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 5 http://$HOST_ADDRESS:8081/health >/dev/null 2>&1; then
        echo "✅ Accessible"
        BACKEND_ACCESSIBLE=true
    else
        echo "❌ Not accessible"
        BACKEND_ACCESSIBLE=false
    fi
    
    # Test frontend
    echo -n "   Frontend ($HOST_ADDRESS:3002): "
    if docker exec "$CONTAINER_NAME" curl -s --connect-timeout 5 http://$HOST_ADDRESS:3002 >/dev/null 2>&1; then
        echo "✅ Accessible"
        FRONTEND_ACCESSIBLE=true
    else
        echo "❌ Not accessible"
        FRONTEND_ACCESSIBLE=false
    fi
    
    if [ "$BACKEND_ACCESSIBLE" = true ] && [ "$FRONTEND_ACCESSIBLE" = true ]; then
        echo ""
        echo "🎉 Both services accessible! Ready for NPM configuration."
        echo ""
        echo "📋 NPM Configuration Details:"
        echo "   Frontend URL: http://$HOST_ADDRESS:3002"
        echo "   Backend URL: http://$HOST_ADDRESS:8081"
        echo "   Domain: chat.it.yrefy"
        echo "   SSL: Use existing it.yrefy certificate"
    fi
fi

echo ""
echo "3. 📱 NPM Web Interface Access:"
echo "   Local: http://127.0.0.1:81"
echo "   Network: http://192.168.128.82:81"
echo "   Default login: admin@example.com / changeme"
echo ""

# Check if services need to be reconfigured
if [ -z "$HOST_ADDRESS" ]; then
    echo "4. 🔧 Service Reconfiguration Required:"
    echo ""
    
    cat << 'EOF'
Since NPM container cannot reach your LLM services, we need to:

Option A: Bind LLM services to all interfaces (Recommended)
---------------------------------------------------------
1. Update ecosystem.config.js:
   HOST: '0.0.0.0' (instead of '127.0.0.1')
   
2. Restart PM2 services:
   pm2 restart yrefy-llm-backend yrefy-llm-frontend

Option B: Add LLM services to NPM Docker network
-----------------------------------------------
1. Stop LLM services: pm2 stop yrefy-llm-backend yrefy-llm-frontend
2. Run services in Docker with shared network:
   docker run --network nginx-proxy-manager_npm_network ...

Option C: Use host networking for NPM (Less secure)
--------------------------------------------------
1. Update docker-compose.yml to use: network_mode: host
EOF

    echo ""
    echo "🎯 Recommended: Choose Option A (bind to 0.0.0.0)"
    echo "   This is simplest and maintains your current PM2 setup"

else
    echo "4. 🌐 NPM Proxy Host Configuration:"
    echo ""
    echo "Ready to configure chat.it.yrefy in NPM web interface!"
    echo ""
    echo "Configuration values for NPM:"
    echo "   Domain: chat.it.yrefy"
    echo "   Forward to: $HOST_ADDRESS:3002"
    echo "   SSL: Use existing it.yrefy certificate"
    echo "   Enable websockets: Yes (for real-time features)"
fi

echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Fix network connectivity (if needed)"
echo "2. Access NPM web interface: http://192.168.128.82:81"
echo "3. Add new proxy host for chat.it.yrefy"
echo "4. Configure SSL with existing it.yrefy certificate"
echo "5. Test chat.it.yrefy access"