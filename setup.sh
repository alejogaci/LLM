#!/bin/bash

echo "========================================="
echo "  Trend Micro AI - Setup (Instalación)"
echo "========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Verificar Python
echo -e "${YELLOW}[1/5] Verificando Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python encontrado: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}✗ Python 3 no está instalado${NC}"
    echo "Instala Python 3.8+ con:"
    echo "  sudo apt update"
    echo "  sudo apt install python3 python3-pip python3-venv -y"
    exit 1
fi

# Verificar que python3-venv está instalado
echo -e "${YELLOW}Verificando python3-venv...${NC}"
if python3 -m venv --help &> /dev/null; then
    echo -e "${GREEN}✓ python3-venv disponible${NC}"
else
    echo -e "${RED}✗ python3-venv no está instalado${NC}"
    echo "Instalando python3-venv..."
    sudo apt update
    sudo apt install python3-venv -y
fi

# 2. Verificar/Instalar Ollama
echo ""
echo -e "${YELLOW}[2/5] Verificando Ollama...${NC}"
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama ya instalado${NC}"
else
    echo -e "${YELLOW}Instalando Ollama...${NC}"
    curl -fsSL https://ollama.ai/install.sh | sh
    echo -e "${GREEN}✓ Ollama instalado${NC}"
fi

# 3. Crear entorno virtual
echo ""
echo -e "${YELLOW}[3/5] Creando entorno virtual Python...${NC}"

# Eliminar venv anterior si existe y está corrupto
if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
    echo -e "${YELLOW}Eliminando venv corrupto...${NC}"
    rm -rf venv
fi

# Crear venv
if [ ! -d "venv" ]; then
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Error creando entorno virtual${NC}"
        echo "Intenta instalar python3-venv manualmente:"
        echo "  sudo apt install python3-venv -y"
        exit 1
    fi
fi

# Verificar que se creó correctamente
if [ -f "venv/bin/activate" ]; then
    echo -e "${GREEN}✓ Entorno virtual creado${NC}"
else
    echo -e "${RED}✗ Error: venv/bin/activate no existe${NC}"
    exit 1
fi

# Activar entorno virtual
source venv/bin/activate

# 4. Instalar dependencias Python
echo ""
echo -e "${YELLOW}[4/5] Instalando dependencias (Flask, Requests)...${NC}"
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
echo -e "${GREEN}✓ Dependencias instaladas${NC}"

# 5. Descargar modelo LLM
echo ""
echo -e "${YELLOW}[5/5] Descargando modelo de IA (llama3.2)...${NC}"
if ollama list 2>/dev/null | grep -q "llama3.2"; then
    echo -e "${GREEN}✓ Modelo llama3.2 ya descargado${NC}"
else
    echo -e "${YELLOW}Descargando... (esto puede tardar 5-10 min)${NC}"
    ollama pull llama3.2
    echo -e "${GREEN}✓ Modelo llama3.2 descargado${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ¡Setup completado!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Para iniciar la aplicación ejecuta:${NC}"
echo "   ./run.sh"
echo ""
