#!/bin/bash
# Docker Nginx Discovery Script
# Analyze Docker Nginx setup for LLM integration

echo "🐳 Docker Nginx Discovery for LLM Integration"
echo "============================================="
echo "Analyzing Docker Nginx setup and configuration"
echo ""

# Create analysis directory
mkdir -p /home/yrefy-it/yrefy-llm/docker-analysis
cd /home/yrefy-it/yrefy-llm/docker-analysis

echo "📊 Docker System Overview:"
echo "=========================="
echo "Docker version: $(docker --version 2>/dev/null || echo 'Docker not found in PATH')"
echo "Docker Compose version: $(docker-compose --version 2>/dev/null || echo 'Docker Compose not found')"
echo ""

# Find running containers
echo "🐳 Running Docker Containers:"
echo "============================="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}" 2>/dev/null || echo "Cannot access Docker (permission issue?)"
echo ""

# Look for Nginx containers specifically
echo "🌐 Nginx Container Analysis:"
echo "============================"
NGINX_CONTAINERS=$(docker ps --filter "ancestor=nginx" --format "{{.Names}}" 2>/dev/null)
if [ -z "$NGINX_CONTAINERS" ]; then
    # Try broader search
    NGINX_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -i nginx 2>/dev/null)
fi

if [ -z "$NGINX_CONTAINERS" ]; then
    echo "❌ No Nginx containers found with 'nginx' in name/image"
    echo "   Searching all containers for port 80/443..."
    
    # Check all containers for web ports
    docker ps --format "{{.Names}}\t{{.Ports}}" | while read container_info; do
        if echo "$container_info" | grep -E ":80|:443" >/dev/null; then
            container_name=$(echo "$container_info" | cut -f1)
            echo "   📦 Container with web ports: $container_name"
            echo "      Ports: $(echo "$container_info" | cut -f2)"
            
            # Check if it's nginx
            if docker exec "$container_name" nginx -v >/dev/null 2>&1; then
                echo "      ✅ Contains Nginx!"
                NGINX_CONTAINERS="$container_name"
            fi
        fi
    done
else
    echo "✅ Found Nginx containers:"
    for container in $NGINX_CONTAINERS; do
        echo "   📦 Container: $container"
        echo "      Image: $(docker inspect "$container" --format '{{.Config.Image}}' 2>/dev/null)"
        echo "      Ports: $(docker port "$container" 2>/dev/null | tr '\n' ' ')"
        echo "      Status: $(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null)"
    done
fi

# Analyze the first/main Nginx container
if [ -n "$NGINX_CONTAINERS" ]; then
    MAIN_NGINX=$(echo "$NGINX_CONTAINERS" | head -1)
    echo ""
    echo "🔍 Analyzing main Nginx container: $MAIN_NGINX"
    echo "=============================================="
    
    # Get container details
    echo "📋 Container Details:" > "nginx-container-$MAIN_NGINX-details.txt"
    docker inspect "$MAIN_NGINX" >> "nginx-container-$MAIN_NGINX-details.txt" 2>/dev/null
    
    # Check mounts and volumes
    echo "📁 Mounted Volumes:"
    docker inspect "$MAIN_NGINX" --format '{{range .Mounts}}{{.Source}} → {{.Destination}} ({{.Type}}){{"\n"}}{{end}}' 2>/dev/null | while read mount; do
        echo "   $mount"
    done
    
    # Check network configuration
    echo ""
    echo "🌐 Network Configuration:"
    docker inspect "$MAIN_NGINX" --format '{{range $k, $v := .NetworkSettings.Networks}}Network: {{$k}}, IP: {{$v.IPAddress}}{{"\n"}}{{end}}' 2>/dev/null
    
    # Check nginx configuration inside container
    echo ""
    echo "⚙️  Nginx Configuration:"
    if docker exec "$MAIN_NGINX" test -f /etc/nginx/nginx.conf 2>/dev/null; then
        echo "   ✅ Main config: /etc/nginx/nginx.conf"
        echo "--- nginx.conf content ---" > "nginx-container-nginx.conf.txt"
        docker exec "$MAIN_NGINX" cat /etc/nginx/nginx.conf >> "nginx-container-nginx.conf.txt" 2>/dev/null
    fi
    
    if docker exec "$MAIN_NGINX" test -d /etc/nginx/sites-available 2>/dev/null; then
        echo "   ✅ Sites available: /etc/nginx/sites-available/"
        echo "--- sites-available listing ---" > "nginx-container-sites-available.txt"
        docker exec "$MAIN_NGINX" ls -la /etc/nginx/sites-available/ >> "nginx-container-sites-available.txt" 2>/dev/null
    fi
    
    if docker exec "$MAIN_NGINX" test -d /etc/nginx/conf.d 2>/dev/null; then
        echo "   ✅ Conf.d directory: /etc/nginx/conf.d/"
        echo "--- conf.d listing ---" > "nginx-container-conf.d.txt"
        docker exec "$MAIN_NGINX" ls -la /etc/nginx/conf.d/ >> "nginx-container-conf.d.txt" 2>/dev/null
    fi
    
    # Check for existing yrefy configurations
    echo ""
    echo "🔍 Searching for yrefy configurations..."
    if docker exec "$MAIN_NGINX" find /etc/nginx -name "*yrefy*" -type f 2>/dev/null | head -10; then
        docker exec "$MAIN_NGINX" find /etc/nginx -name "*yrefy*" -type f -exec cat {} \; > "nginx-container-yrefy-configs.txt" 2>/dev/null
        echo "   ✅ Found yrefy configs (saved to nginx-container-yrefy-configs.txt)"
    else
        echo "   ⚠️  No files with 'yrefy' in name found"
    fi
    
    # Check for it.yrefy specifically
    if docker exec "$MAIN_NGINX" grep -r "it.yrefy" /etc/nginx/ 2>/dev/null | head -5; then
        echo "   ✅ Found it.yrefy references"
        echo "--- it.yrefy configurations ---" > "nginx-container-it.yrefy-config.txt"
        docker exec "$MAIN_NGINX" grep -r "it.yrefy" /etc/nginx/ >> "nginx-container-it.yrefy-config.txt" 2>/dev/null
    else
        echo "   ⚠️  No it.yrefy references found in configs"
    fi
    
    # Check SSL certificates
    echo ""
    echo "🔒 SSL Certificates in container:"
    docker exec "$MAIN_NGINX" find /etc -name "*yrefy*" \( -name "*.crt" -o -name "*.pem" -o -name "*.key" \) 2>/dev/null | while read cert; do
        echo "   📜 Certificate: $cert"
    done
    
else
    echo "❌ No Nginx containers found"
fi

# Check Docker Compose setup
echo ""
echo "🐙 Docker Compose Analysis:"
echo "=========================="

# Look for docker-compose files
find /home/yrefy-it -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | head -5 | while read compose_file; do
    echo "📄 Found compose file: $compose_file"
    if grep -i nginx "$compose_file" >/dev/null 2>&1; then
        echo "   ✅ Contains Nginx configuration"
        echo "--- $compose_file (nginx relevant parts) ---" > "docker-compose-$(basename $(dirname $compose_file)).txt"
        grep -A 20 -B 5 -i nginx "$compose_file" >> "docker-compose-$(basename $(dirname $compose_file)).txt" 2>/dev/null
    fi
done

# Check common Docker directories
for dir in "/opt/docker" "/home/yrefy-it/docker" "/root/docker" "/var/lib/docker" "/docker"; do
    if [ -d "$dir" ]; then
        echo "📁 Found Docker directory: $dir"
        find "$dir" -name "docker-compose.yml" -o -name "*.yml" | head -3 | while read file; do
            if grep -i nginx "$file" >/dev/null 2>&1; then
                echo "   📄 Nginx compose file: $file"
            fi
        done
    fi
done

# Check networking for LLM integration
echo ""
echo "🌉 Docker Network Analysis:"
echo "=========================="

if [ -n "$NGINX_CONTAINERS" ]; then
    MAIN_NGINX=$(echo "$NGINX_CONTAINERS" | head -1)
    
    # Get container IP
    CONTAINER_IP=$(docker inspect "$MAIN_NGINX" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -1)
    echo "📍 Nginx container IP: $CONTAINER_IP"
    
    # Check if host network mode
    NETWORK_MODE=$(docker inspect "$MAIN_NGINX" --format '{{.HostConfig.NetworkMode}}' 2>/dev/null)
    echo "🌐 Network mode: $NETWORK_MODE"
    
    # List Docker networks
    echo ""
    echo "🌉 Available Docker networks:"
    docker network ls 2>/dev/null | while read line; do
        echo "   $line"
    done
fi

# Test connectivity to LLM services
echo ""
echo "🧪 Testing LLM Service Connectivity:"
echo "===================================="

echo "Host services:"
echo "   Backend (8081): $(curl -s http://127.0.0.1:8081/health >/dev/null && echo 'Accessible' || echo 'Not accessible')"
echo "   Frontend (3002): $(curl -s http://127.0.0.1:3002 >/dev/null && echo 'Accessible' || echo 'Not accessible')"

if [ -n "$NGINX_CONTAINERS" ]; then
    MAIN_NGINX=$(echo "$NGINX_CONTAINERS" | head -1)
    echo ""
    echo "From Nginx container:"
    
    # Test from container to host services
    echo "   To host 127.0.0.1:8081: $(docker exec "$MAIN_NGINX" curl -s --connect-timeout 5 http://127.0.0.1:8081/health >/dev/null 2>&1 && echo 'Accessible' || echo 'Not accessible')"
    echo "   To host 192.168.128.82:8081: $(docker exec "$MAIN_NGINX" curl -s --connect-timeout 5 http://192.168.128.82:8081/health >/dev/null 2>&1 && echo 'Accessible' || echo 'Not accessible')"
    echo "   To host.docker.internal:8081: $(docker exec "$MAIN_NGINX" curl -s --connect-timeout 5 http://host.docker.internal:8081/health >/dev/null 2>&1 && echo 'Accessible' || echo 'Not accessible')"
fi

echo ""
echo "📋 Integration Strategy Summary:"
echo "==============================="
echo ""
echo "Based on the analysis above, we need to:"
echo ""
if [ -n "$NGINX_CONTAINERS" ]; then
    echo "✅ Docker Nginx container found: $(echo "$NGINX_CONTAINERS" | head -1)"
    echo "1. 📁 Determine how to add configuration files to the container"
    echo "2. 🌐 Configure networking between container and host LLM services"
    echo "3. 🔒 Ensure SSL certificates are accessible to container"
    echo "4. 🔄 Determine how to reload/restart the container configuration"
else
    echo "❌ No Nginx container found - need to investigate further"
fi
echo ""
echo "📁 Analysis files created:"
ls -la *.txt 2>/dev/null | while read file; do
    echo "   $file"
done

echo ""
echo "🎯 Next Steps:"
echo "1. Review the generated analysis files"
echo "2. Identify the Docker Nginx configuration method"
echo "3. Plan the chat.it.yrefy integration approach"
echo "4. Test networking between Docker container and host services"

echo ""
echo "📄 Key files to review:"
echo "   • nginx-container-*-details.txt - Container configuration"
echo "   • docker-compose-*.txt - Docker Compose setup"
echo "   • nginx-container-yrefy-configs.txt - Existing configs"