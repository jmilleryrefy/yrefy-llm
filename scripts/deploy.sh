#!/bin/bash
# Quick deployment script

set -e

echo "🚀 Deploying Yrefy LLM System"
echo "=============================="

cd /home/yrefy-it/yrefy-llm

# Stop existing PM2 processes
echo "🛑 Stopping existing services..."
pm2 delete ecosystem.config.js 2>/dev/null || echo "  (No existing processes to stop)"

# Test backend dependencies quickly
echo "🐍 Checking backend..."
cd backend
source venv/bin/activate
python -c "import flask, msal, requests; print('✅ Backend dependencies OK')"
cd ..

# Test frontend build
echo "⚛️ Checking frontend..."
cd frontend
if [ ! -d ".next" ]; then
    echo "  🔨 Building frontend..."
    npm run build
fi
cd ..

# Start services with PM2
echo "📦 Starting services with PM2..."
pm2 start ecosystem.config.js

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 5

# Check status
pm2 status

# Test connectivity
echo ""
echo "🌐 Testing services..."
sleep 2

# Test backend
if curl -s http://localhost:8081/health > /dev/null; then
    echo "✅ Backend responding on port 8081"
    curl -s http://localhost:8081/health | head -3
else
    echo "❌ Backend not responding"
fi

# Test frontend
if curl -s http://localhost:3002 > /dev/null; then
    echo "✅ Frontend responding on port 3002"
else
    echo "❌ Frontend not responding"
fi

# Save PM2 config
pm2 save

echo ""
echo "✅ Deployment Complete!"
echo "🌐 Access your LLM: http://localhost:3002"
echo "📊 PM2 status: pm2 status"
echo "📝 View logs: pm2 logs"
