#!/bin/bash

echo "=========================================="
echo "  Trend Micro AI - Iniciando Aplicación"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar que existe venv
if [ ! -d "venv" ]; then
    echo -e "${RED}✗ Setup no completado${NC}"
    echo "Ejecuta primero: ./setup.sh"
    exit 1
fi

# Crear carpeta de logs
mkdir -p logs
touch logs/ollama.log
touch logs/app.log

# Activar entorno virtual
source venv/bin/activate

# 1. Iniciar Ollama en segundo plano
echo -e "${YELLOW}[1/2] Iniciando Ollama...${NC}"
if pgrep -x "ollama" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama ya está corriendo${NC}"
else
    nohup ollama serve > logs/ollama.log 2>&1 &
    OLLAMA_PID=$!
    sleep 3
    
    if pgrep -x "ollama" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ollama iniciado (PID: $OLLAMA_PID)${NC}"
    else
        echo -e "${RED}✗ Error al iniciar Ollama${NC}"
        echo "Revisa logs/ollama.log"
        exit 1
    fi
fi

# 2. Iniciar aplicación Flask en segundo plano
echo ""
echo -e "${YELLOW}[2/2] Iniciando aplicación Flask...${NC}"

# Verificar si puerto 5000 está en uso
if command -v lsof &> /dev/null; then
    if lsof -ti:5000 > /dev/null 2>&1; then
        echo -e "${YELLOW}! Puerto 5000 en uso, deteniendo proceso anterior...${NC}"
        kill -9 $(lsof -ti:5000) 2>/dev/null
        sleep 2
    fi
fi

# Usar python3 explícitamente
nohup python3 app.py > logs/app.log 2>&1 &
APP_PID=$!
sleep 3

# Verificar que la app está corriendo
if ps -p $APP_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Aplicación iniciada (PID: $APP_PID)${NC}"
else
    echo -e "${RED}✗ Error al iniciar aplicación${NC}"
    echo "Contenido del log:"
    echo ""
    cat logs/app.log
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ¡Aplicación funcionando!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Acceso:${NC}           http://localhost:5000"
echo -e "${BLUE}Logs Ollama:${NC}      tail -f logs/ollama.log"
echo -e "${BLUE}Logs App:${NC}         tail -f logs/app.log"
echo ""
echo -e "${YELLOW}Para detener:${NC}     ./stop.sh"
echo -e "${YELLOW}Para ver estado:${NC}  ./status.sh"
echo ""
