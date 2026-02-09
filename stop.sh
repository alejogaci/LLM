#!/bin/bash

echo "=========================================="
echo "  Trend Micro AI - Deteniendo Aplicación"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Detener aplicación Flask
echo -e "${YELLOW}[1/2] Deteniendo aplicación Flask...${NC}"
if lsof -ti:5000 > /dev/null 2>&1; then
    kill -9 $(lsof -ti:5000) 2>/dev/null
    sleep 1
    echo -e "${GREEN}✓ Aplicación detenida${NC}"
else
    echo -e "${YELLOW}! Aplicación no está corriendo${NC}"
fi

# 2. Detener Ollama
echo ""
echo -e "${YELLOW}[2/2] Deteniendo Ollama...${NC}"
if pgrep -x "ollama" > /dev/null; then
    pkill -9 ollama
    sleep 1
    echo -e "${GREEN}✓ Ollama detenido${NC}"
else
    echo -e "${YELLOW}! Ollama no está corriendo${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Todo detenido${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
