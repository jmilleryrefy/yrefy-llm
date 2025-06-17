#!/bin/bash
# Pre-deployment verification for Yrefy LLM

echo "🔍 Pre-Deployment Verification for Yrefy LLM"
echo "============================================="

# Check current directory
echo "📁 Current directory:"
pwd
echo ""

# Check if we're in the right location
if [[ ! -f "ecosystem.config.js" ]]; then
    echo "❌ ERROR: ecosystem.config.js not found. Please run from project root."
    exit 1
fi

# Check backend setup
echo "🐍 Backend Check:"
if [[ -d "backend/venv" ]]; then
    echo "  ✅ Virtual environment exists"
else
    echo "  ❌ Virtual environment missing"
fi

if [[ -f "backend/.env" ]]; then
    echo "  ✅ Backend .env file exists"
else
    echo "  ❌ Backend .env file missing"
fi

if [[ -f "backend/app.py" ]]; then
    echo "  ✅ Backend app.py exists"
else
    echo "  ❌ Backend app.py missing"
fi

# Check frontend setup
echo ""
echo "⚛️ Frontend Check:"
if [[ -d "frontend/node_modules" ]]; then
    echo "  ✅ Node modules installed"
else
    echo "  ❌ Node modules missing - run 'npm install' in frontend/"
fi

if [[ -f "frontend/.env.local" ]]; then
    echo "  ✅ Frontend .env.local exists"
else
    echo "  ❌ Frontend .env.local missing"
fi

# Check PM2 installation
echo ""
echo "📦 PM2 Check:"
if command -v pm2 &> /dev/null; then
    echo "  ✅ PM2 is installed"
    pm2 --version
else
    echo "  ❌ PM2 not installed. Install with: npm install -g pm2"
fi

# Check Ollama connectivity
echo ""
echo "🤖 Ollama Check:"
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "  ✅ Ollama is running and accessible"
else
    echo "  ⚠️  Ollama not accessible at localhost:11434"
    echo "     Make sure Ollama is running: ollama serve"
fi

# Check data directory
echo ""
echo "💾 Data Directory Check:"
if [[ -d "data" ]]; then
    echo "  ✅ Data directory exists"
    if [[ -d "data/logs" ]]; then
        echo "  ✅ Logs directory exists"
    else
        echo "  ⚠️  Creating logs directory..."
        mkdir -p data/logs
    fi
else
    echo "  ⚠️  Creating data directory..."
    mkdir -p data/logs
fi

echo ""
echo "🎯 Summary:"
echo "  - Backend: $([ -d "backend/venv" ] && echo "✅ Ready" || echo "❌ Needs setup")"
echo "  - Frontend: $([ -d "frontend/node_modules" ] && echo "✅ Ready" || echo "❌ Needs setup")"
echo "  - PM2: $(command -v pm2 &> /dev/null && echo "✅ Ready" || echo "❌ Needs install")"
echo "  - Ollama: $(curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && echo "✅ Ready" || echo "⚠️  Check status")"
echo ""
echo "Ready to deploy? Run: ./scripts/deploy.sh"