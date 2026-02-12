#!/bin/bash

echo "=========================================="
echo "  Trend Micro AI - Stopping Application"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Stop Flask application
echo -e "${YELLOW}[1/2] Stopping Flask application...${NC}"
if lsof -ti:5000 > /dev/null 2>&1; then
    kill -9 $(lsof -ti:5000) 2>/dev/null
    sleep 1
    echo -e "${GREEN}✓ Application stopped${NC}"
else
    echo -e "${YELLOW}! Application not running${NC}"
fi

# 2. Stop Ollama
echo ""
echo -e "${YELLOW}[2/2] Stopping Ollama...${NC}"
if pgrep -x "ollama" > /dev/null; then
    pkill -9 ollama
    sleep 1
    echo -e "${GREEN}✓ Ollama stopped${NC}"
else
    echo -e "${YELLOW}! Ollama not running${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Everything stopped${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
