#!/bin/bash
# Final verification of LLM system

echo "🔍 Final LLM System Verification"
echo "================================="

# Start Ollama if not running
echo "1. Starting Ollama..."
if ! pgrep -f "ollama serve" > /dev/null; then
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    echo "   Ollama started in background"
    sleep 5
else
    echo "   Ollama already running"
fi

# Test all components
echo ""
echo "2. Testing System Components:"

# Test Ollama
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "   ✅ Ollama: Responding on port 11434"
    model_count=$(curl -s http://localhost:11434/api/tags | jq '.models | length' 2>/dev/null || echo "N/A")
    echo "      Models available: $model_count"
else
    echo "   ❌ Ollama: Not responding"
fi

# Test Backend
if curl -s http://localhost:8081/health > /dev/null; then
    echo "   ✅ Backend: Responding on port 8081"
    health_status=$(curl -s http://localhost:8081/health | jq -r '.status' 2>/dev/null || echo "unknown")
    echo "      Health status: $health_status"
else
    echo "   ❌ Backend: Not responding"
fi

# Test Frontend
if curl -s http://localhost:3002 > /dev/null; then
    echo "   ✅ Frontend: Responding on port 3002"
else
    echo "   ❌ Frontend: Not responding"
fi

echo ""
echo "3. PM2 Status:"
pm2 status | grep yrefy-llm

echo ""
echo "4. Port Usage:"
echo "   Port 8081 (Backend):  $(lsof -i :8081 | wc -l) connections"
echo "   Port 3002 (Frontend): $(lsof -i :3002 | wc -l) connections"
echo "   Port 11434 (Ollama):  $(lsof -i :11434 | wc -l) connections"

echo ""
echo "5. Full Health Check:"
curl -s http://localhost:8081/health | jq . 2>/dev/null || curl -s http://localhost:8081/health

echo ""
echo "🎯 System Summary:"
if curl -s http://localhost:8081/health | grep -q '"status":"healthy"'; then
    echo "   Status: 🟢 FULLY OPERATIONAL"
    echo ""
    echo "🎉 Your LLM System is Ready!"
    echo "   🌐 Access: http://localhost:3002"
    echo "   🔧 API: http://localhost:8081"
    echo "   🤖 Ollama: http://localhost:11434"
    echo ""
    echo "💡 Quick Tests:"
    echo "   curl http://localhost:8081/health"
    echo "   curl http://localhost:8081/api/models"
    echo ""
    echo "📊 Monitoring:"
    echo "   pm2 status"
    echo "   pm2 logs yrefy-llm-backend"
    echo "   pm2 logs yrefy-llm-frontend"
else
    echo "   Status: 🟡 NEEDS ATTENTION"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   Check backend logs: pm2 logs yrefy-llm-backend"
    echo "   Check Ollama: curl http://localhost:11434/api/tags"
    echo "   Restart if needed: pm2 restart yrefy-llm-backe