#!/bin/bash

echo "=========================================="
echo "  Trend Micro AI - System Status"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Check Ollama
echo -e "${BLUE}[Ollama]${NC}"
if pgrep -x "ollama" > /dev/null; then
    OLLAMA_PID=$(pgrep -x "ollama")
    echo -e "  Status: ${GREEN}✓ Running${NC} (PID: $OLLAMA_PID)"
    
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "  API:    ${GREEN}✓ Responding${NC} (http://localhost:11434)"
    else
        echo -e "  API:    ${RED}✗ Not responding${NC}"
    fi
else
    echo -e "  Status: ${RED}✗ Not running${NC}"
fi

echo ""

# 2. Check Flask Application
echo -e "${BLUE}[Flask Application]${NC}"
if lsof -ti:5000 > /dev/null 2>&1; then
    APP_PID=$(lsof -ti:5000)
    echo -e "  Status: ${GREEN}✓ Running${NC} (PID: $APP_PID)"
    echo -e "  Port:   ${GREEN}✓ 5000 active${NC}"
    echo -e "  URL:    ${GREEN}http://localhost:5000${NC}"
else
    echo -e "  Status: ${RED}✗ Not running${NC}"
fi

echo ""

# 3. Recent Logs
echo -e "${BLUE}[Recent Logs]${NC}"
if [ -f "logs/app.log" ]; then
    echo -e "  App:    ${GREEN}logs/app.log${NC} (last 3 lines)"
    echo "  ---"
    tail -n 3 logs/app.log | sed 's/^/  /'
else
    echo -e "  App:    ${YELLOW}No logs${NC}"
fi

echo ""

if [ -f "logs/ollama.log" ]; then
    echo -e "  Ollama: ${GREEN}logs/ollama.log${NC} (last 3 lines)"
    echo "  ---"
    tail -n 3 logs/ollama.log | sed 's/^/  /'
else
    echo -e "  Ollama: ${YELLOW}No logs${NC}"
fi

echo ""
echo "=========================================="
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  View app logs:     tail -f logs/app.log"
echo "  View Ollama logs:  tail -f logs/ollama.log"
echo "  Stop all:          ./stop.sh"
echo "  Restart:           ./stop.sh && ./run.sh"
echo ""
