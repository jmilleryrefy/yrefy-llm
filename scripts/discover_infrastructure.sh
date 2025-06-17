#!/bin/bash
# Infrastructure Discovery Script
# Gather information about existing BIND8 and Nginx setup

echo "🔍 Infrastructure Discovery for LLM Integration"
echo "=============================================="
echo "Analyzing existing BIND8 DNS and Nginx setup"
echo ""

# Create output directory
mkdir -p /home/yrefy-it/yrefy-llm/infrastructure-analysis
cd /home/yrefy-it/yrefy-llm/infrastructure-analysis

echo "📊 System Overview:"
echo "=================="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# BIND8/DNS Analysis
echo "🌐 BIND8/DNS Configuration Analysis:"
echo "===================================="

# Check if BIND is running
if systemctl is-active --quiet named; then
    echo "✅ BIND8/named service: ACTIVE"
    echo "   Status: $(systemctl status named --no-pager -l | grep Active)"
else
    echo "❌ BIND8/named service: INACTIVE"
fi

# Find BIND configuration files
echo ""
echo "📁 BIND Configuration Files:"
if [ -f /etc/bind/named.conf ]; then
    echo "   Main config: /etc/bind/named.conf"
fi
if [ -f /etc/bind/named.conf.local ]; then
    echo "   Local zones: /etc/bind/named.conf.local"
fi
if [ -f /etc/bind/named.conf.options ]; then
    echo "   Options: /etc/bind/named.conf.options"
fi

# Analyze named.conf.local for yrefy domain
echo ""
echo "🔍 Searching for yrefy domain configuration..."
if [ -f /etc/bind/named.conf.local ]; then
    echo "--- named.conf.local content ---" > bind-named.conf.local.txt
    cat /etc/bind/named.conf.local >> bind-named.conf.local.txt
    
    if grep -q "yrefy" /etc/bind/named.conf.local; then
        echo "✅ Found yrefy domain configuration:"
        grep -A 10 -B 2 "yrefy" /etc/bind/named.conf.local | head -20
    else
        echo "⚠️  No yrefy domain found in named.conf.local"
    fi
else
    echo "❌ /etc/bind/named.conf.local not found"
fi

# Find zone files
echo ""
echo "📄 Zone Files:"
find /etc/bind/ -name "*yrefy*" -type f 2>/dev/null | while read zonefile; do
    echo "   Found: $zonefile"
    echo "--- $zonefile content ---" > "zone-$(basename $zonefile).txt"
    cat "$zonefile" >> "zone-$(basename $zonefile).txt"
done

# Find any zone files that might contain yrefy
find /etc/bind/ -name "db.*" -type f -exec grep -l "yrefy" {} \; 2>/dev/null | while read zonefile; do
    echo "   Zone file with yrefy: $zonefile"
    echo "--- $zonefile content ---" > "zone-$(basename $zonefile).txt"
    cat "$zonefile" >> "zone-$(basename $zonefile).txt"
done

# Test DNS resolution
echo ""
echo "🧪 DNS Resolution Tests:"
echo "   it.yrefy: $(nslookup it.yrefy 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo 'NOT RESOLVED')"
echo "   chat.it.yrefy: $(nslookup chat.it.yrefy 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo 'NOT RESOLVED')"

# Nginx Analysis
echo ""
echo "🌐 Nginx Configuration Analysis:"
echo "==============================="

# Check if Nginx is running
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx service: ACTIVE"
    echo "   Status: $(systemctl status nginx --no-pager -l | grep Active)"
    echo "   Version: $(nginx -v 2>&1)"
else
    echo "❌ Nginx service: INACTIVE"
fi

# Find Nginx configuration files
echo ""
echo "📁 Nginx Configuration Structure:"
if [ -f /etc/nginx/nginx.conf ]; then
    echo "   Main config: /etc/nginx/nginx.conf"
fi

if [ -d /etc/nginx/sites-available ]; then
    echo "   Sites available: /etc/nginx/sites-available/"
    ls -la /etc/nginx/sites-available/ | grep -v "^total" | while read line; do
        echo "      $line"
    done
fi

if [ -d /etc/nginx/sites-enabled ]; then
    echo "   Sites enabled: /etc/nginx/sites-enabled/"
    ls -la /etc/nginx/sites-enabled/ | grep -v "^total" | while read line; do
        echo "      $line"
    done
fi

# Analyze sites for yrefy domain
echo ""
echo "🔍 Searching for yrefy configurations in Nginx..."
find /etc/nginx/sites-available/ -type f -exec grep -l "yrefy" {} \; 2>/dev/null | while read conffile; do
    echo "✅ Found yrefy config: $conffile"
    echo "--- $(basename $conffile) content ---" > "nginx-$(basename $conffile).txt"
    cat "$conffile" >> "nginx-$(basename $conffile).txt"
    
    echo "   Key configurations:"
    grep -E "(server_name|listen|location|proxy_pass)" "$conffile" 2>/dev/null | head -10 | while read line; do
        echo "      $line"
    done
done

# Check what's listening on ports
echo ""
echo "🔌 Port Analysis:"
echo "   Port 80 (HTTP):"
netstat -tlnp 2>/dev/null | grep ":80 " || ss -tlnp | grep ":80 "
echo "   Port 443 (HTTPS):"
netstat -tlnp 2>/dev/null | grep ":443 " || ss -tlnp | grep ":443 "
echo "   Port 3002 (potential LLM frontend):"
netstat -tlnp 2>/dev/null | grep ":3002 " || ss -tlnp | grep ":3002 " || echo "      Not in use"
echo "   Port 8081 (potential LLM backend):"
netstat -tlnp 2>/dev/null | grep ":8081 " || ss -tlnp | grep ":8081 " || echo "      Not in use"

# SSL Certificate Analysis
echo ""
echo "🔒 SSL Certificate Analysis:"
if [ -d /etc/nginx/ssl ]; then
    echo "   SSL directory: /etc/nginx/ssl/"
    ls -la /etc/nginx/ssl/ | grep yrefy || echo "   No yrefy certificates found"
fi

# Look for certificates in other common locations
find /etc/ -name "*yrefy*" -name "*.crt" -o -name "*yrefy*" -name "*.pem" -o -name "*yrefy*" -name "*.key" 2>/dev/null | while read cert; do
    echo "   Certificate found: $cert"
    echo "   Details: $(openssl x509 -in "$cert" -text -noout 2>/dev/null | grep -E "(Subject:|DNS:|IP Address:)" | head -3 || echo 'Cannot read certificate')"
done

# Test current it.yrefy website
echo ""
echo "🌐 Current it.yrefy Website Test:"
if curl -k -s -o /dev/null -w "%{http_code}" https://it.yrefy 2>/dev/null | grep -q "200\|301\|302"; then
    echo "✅ it.yrefy is accessible via HTTPS"
    echo "   Response code: $(curl -k -s -o /dev/null -w "%{http_code}" https://it.yrefy 2>/dev/null)"
else
    echo "⚠️  it.yrefy not accessible via HTTPS"
fi

if curl -s -o /dev/null -w "%{http_code}" http://it.yrefy 2>/dev/null | grep -q "200\|301\|302"; then
    echo "✅ it.yrefy is accessible via HTTP"
    echo "   Response code: $(curl -s -o /dev/null -w "%{http_code}" http://it.yrefy 2>/dev/null)"
else
    echo "⚠️  it.yrefy not accessible via HTTP"
fi

# PM2 Analysis
echo ""
echo "📦 PM2 Process Analysis:"
if command -v pm2 >/dev/null 2>&1; then
    echo "✅ PM2 is installed"
    echo "   Version: $(pm2 --version)"
    echo ""
    echo "   Current processes:"
    pm2 status || echo "   No PM2 processes running"
else
    echo "⚠️  PM2 not found"
fi

# Summary and Recommendations
echo ""
echo "📋 Configuration Summary:"
echo "========================"
echo ""
echo "📄 Files created for analysis:"
ls -la *.txt 2>/dev/null | while read file; do
    echo "   $file"
done

echo ""
echo "🎯 Recommendations for chat.it.yrefy:"
echo "====================================="
echo ""
echo "Based on this analysis, we need to:"
echo "1. 📍 Add DNS record for chat.it.yrefy subdomain"
echo "2. 🔒 Create/copy SSL certificate for chat.it.yrefy"
echo "3. 🌐 Create new Nginx virtual host for chat.it.yrefy"
echo "4. ⚙️  Configure LLM services to use chat.it.yrefy"
echo "5. 🔐 Update Azure AD for chat.it.yrefy domain"
echo ""
echo "Next steps:"
echo "1. Review the configuration files created above"
echo "2. Confirm the SSL certificate approach"
echo "3. Plan the subdomain integration"
echo ""
echo "📁 All analysis files saved in: $(pwd)"

# Test if we can create chat.it.yrefy record
echo ""
echo "🧪 Testing subdomain creation..."
if nslookup chat.it.yrefy >/dev/null 2>&1; then
    echo "⚠️  chat.it.yrefy already exists: $(nslookup chat.it.yrefy | grep -A 1 "Name:" | tail -1)"
else
    echo "✅ chat.it.yrefy is available for configuration"
fi

echo ""
echo "🎉 Infrastructure analysis complete!"
echo "Review the generated .txt files for detailed configurations."