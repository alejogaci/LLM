#!/bin/bash

echo "=========================================="
echo "  Trend Micro AI - Estado del Sistema"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Verificar Ollama
echo -e "${BLUE}[Ollama]${NC}"
if pgrep -x "ollama" > /dev/null; then
    OLLAMA_PID=$(pgrep -x "ollama")
    echo -e "  Estado: ${GREEN}✓ Corriendo${NC} (PID: $OLLAMA_PID)"
    
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "  API:    ${GREEN}✓ Respondiendo${NC} (http://localhost:11434)"
    else
        echo -e "  API:    ${RED}✗ No responde${NC}"
    fi
else
    echo -e "  Estado: ${RED}✗ No está corriendo${NC}"
fi

echo ""

# 2. Verificar Aplicación Flask
echo -e "${BLUE}[Aplicación Flask]${NC}"
if lsof -ti:5000 > /dev/null 2>&1; then
    APP_PID=$(lsof -ti:5000)
    echo -e "  Estado: ${GREEN}✓ Corriendo${NC} (PID: $APP_PID)"
    echo -e "  Puerto: ${GREEN}✓ 5000 activo${NC}"
    echo -e "  URL:    ${GREEN}http://localhost:5000${NC}"
else
    echo -e "  Estado: ${RED}✗ No está corriendo${NC}"
fi

echo ""

# 3. Logs recientes
echo -e "${BLUE}[Logs Recientes]${NC}"
if [ -f "logs/app.log" ]; then
    echo -e "  App:    ${GREEN}logs/app.log${NC} (últimas 3 líneas)"
    echo "  ---"
    tail -n 3 logs/app.log | sed 's/^/  /'
else
    echo -e "  App:    ${YELLOW}Sin logs${NC}"
fi

echo ""

if [ -f "logs/ollama.log" ]; then
    echo -e "  Ollama: ${GREEN}logs/ollama.log${NC} (últimas 3 líneas)"
    echo "  ---"
    tail -n 3 logs/ollama.log | sed 's/^/  /'
else
    echo -e "  Ollama: ${YELLOW}Sin logs${NC}"
fi

echo ""
echo "=========================================="
echo ""
echo -e "${YELLOW}Comandos útiles:${NC}"
echo "  Ver logs app:    tail -f logs/app.log"
echo "  Ver logs Ollama: tail -f logs/ollama.log"
echo "  Detener todo:    ./stop.sh"
echo "  Reiniciar:       ./stop.sh && ./run.sh"
echo ""
