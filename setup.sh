#!/bin/bash

echo "=========================================="
echo "  Setup - POC AI Guard"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detectar CPUs
CPU_CORES=$(nproc)
echo -e "${BLUE}CPUs detectadas: $CPU_CORES${NC}"
echo ""

# ====================================
# VERIFICAR PYTHON
# ====================================
echo -e "${YELLOW}[1/4] Verificando Python...${NC}"
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

# Verificar python3-venv
if ! dpkg -l | grep -q python3-venv 2>/dev/null; then
    echo "Instalando python3-venv..."
    sudo apt update && sudo apt install -y python3-venv
fi

# ====================================
# INSTALAR OLLAMA
# ====================================
echo ""
echo -e "${YELLOW}[2/4] Verificando Ollama...${NC}"
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama ya está instalado${NC}"
else
    echo -e "${YELLOW}Instalando Ollama...${NC}"
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${GREEN}✓ Ollama instalado${NC}"
fi

# ====================================
# CREAR ENTORNO VIRTUAL PYTHON
# ====================================
echo ""
echo -e "${YELLOW}[3/4] Configurando entorno Python...${NC}"

# Eliminar venv corrupto si existe
if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
    echo -e "${YELLOW}Eliminando venv corrupto...${NC}"
    rm -rf venv
fi

# Crear venv
if [ ! -d "venv" ]; then
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Error creando entorno virtual${NC}"
        exit 1
    fi
fi

# Verificar creación
if [ ! -f "venv/bin/activate" ]; then
    echo -e "${RED}✗ Error: venv/bin/activate no existe${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Entorno virtual creado${NC}"

# Activar venv e instalar dependencias
source venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Dependencias instaladas${NC}"
else
    echo -e "${RED}✗ Error instalando dependencias${NC}"
    exit 1
fi

# ====================================
# DESCARGAR MODELO DOLPHIN LLAMA 3
# ====================================
echo ""
echo -e "${YELLOW}[4/4] Descargando modelo LLM...${NC}"

# Verificar si dolphin-llama3 ya está instalado
if ollama list 2>/dev/null | grep -q "dolphin-llama3"; then
    echo -e "${GREEN}✓ Modelo dolphin-llama3 ya descargado${NC}"
else
    echo -e "${YELLOW}Descargando Dolphin Llama 3 (sin filtros)...${NC}"
    echo -e "${BLUE}Esto puede tardar 5-10 minutos...${NC}"
    ollama pull dolphin-llama3
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Modelo dolphin-llama3 descargado${NC}"
    else
        echo -e "${RED}✗ Error descargando modelo${NC}"
        echo -e "${YELLOW}Puedes descargarlo después con: ollama pull dolphin-llama3${NC}"
    fi
fi

# ====================================
# VERIFICAR ESTRUCTURA
# ====================================
echo ""
echo -e "${YELLOW}Verificando archivos...${NC}"

MISSING=0

if [ ! -f "app.py" ]; then
    echo -e "${RED}✗ Falta app.py${NC}"
    MISSING=$((MISSING + 1))
fi

if [ ! -f "app_guardtrail.py" ]; then
    echo -e "${RED}✗ Falta app_guardtrail.py${NC}"
    MISSING=$((MISSING + 1))
fi

if [ ! -d "templates" ]; then
    echo -e "${RED}✗ Falta carpeta templates/${NC}"
    MISSING=$((MISSING + 1))
fi

if [ ! -d "static" ]; then
    echo -e "${RED}✗ Falta carpeta static/${NC}"
    MISSING=$((MISSING + 1))
fi

if [ $MISSING -gt 0 ]; then
    echo -e "${YELLOW}⚠ Faltan $MISSING archivos/carpetas${NC}"
else
    echo -e "${GREEN}✓ Estructura completa${NC}"
fi

# ====================================
# RESUMEN
# ====================================
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Setup completado${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Configuración:${NC}"
echo "  Modelo: Dolphin Llama 3 (sin filtros)"
echo "  CPUs: $CPU_CORES cores"
echo ""
echo -e "${BLUE}Ejecutar:${NC}"
echo "  ./run.sh               - App SIN AI Guard"
echo "  ./run_guardtrail.sh    - App CON AI Guard"
echo ""
echo -e "${BLUE}Configurar AI Guard (opcional):${NC}"
echo "  export V1_API_KEY=\"tu-api-key\""
echo "  ./run_guardtrail.sh"
echo ""
echo -e "${BLUE}Herramientas:${NC}"
echo "  ./stop.sh              - Detener app"
echo "  ./status.sh            - Ver estado"
echo ""
