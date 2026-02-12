#!/bin/bash

echo "=========================================="
echo "  Setup - POC AI Guard"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect CPUs
CPU_CORES=$(nproc)
echo -e "${BLUE}CPUs detected: $CPU_CORES${NC}"
echo ""

# ====================================
# VERIFY PYTHON
# ====================================
echo -e "${YELLOW}[1/4] Verifying Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python found: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}✗ Python 3 is not installed${NC}"
    echo "Install Python 3.8+ with:"
    echo "  sudo apt update"
    echo "  sudo apt install python3 python3-pip python3-venv -y"
    exit 1
fi

# Verify python3-venv
if ! dpkg -l | grep -q python3-venv 2>/dev/null; then
    echo "Installing python3-venv..."
    sudo apt update && sudo apt install -y python3-venv
fi

# ====================================
# INSTALL OLLAMA
# ====================================
echo ""
echo -e "${YELLOW}[2/4] Verifying Ollama...${NC}"
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama already installed${NC}"
else
    echo -e "${YELLOW}Installing Ollama...${NC}"
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${GREEN}✓ Ollama installed${NC}"
fi

# ====================================
# CREATE PYTHON VIRTUAL ENVIRONMENT
# ====================================
echo ""
echo -e "${YELLOW}[3/4] Configuring Python environment...${NC}"

# Remove corrupted venv if exists
if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
    echo -e "${YELLOW}Removing corrupted venv...${NC}"
    rm -rf venv
fi

# Create venv
if [ ! -d "venv" ]; then
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Error creating virtual environment${NC}"
        exit 1
    fi
fi

# Verify creation
if [ ! -f "venv/bin/activate" ]; then
    echo -e "${RED}✗ Error: venv/bin/activate does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Virtual environment created${NC}"

# Activate venv and install dependencies
source venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${RED}✗ Error installing dependencies${NC}"
    exit 1
fi

# ====================================
# DOWNLOAD DOLPHIN LLAMA 3 MODEL
# ====================================
echo ""
echo -e "${YELLOW}[4/4] Downloading LLM model...${NC}"

# Ensure Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}Starting Ollama service...${NC}"
    nohup ollama serve > /tmp/ollama_setup.log 2>&1 &
    sleep 5
    
    # Verify it started
    if pgrep -x "ollama" > /dev/null; then
        echo -e "${GREEN}✓ Ollama service started${NC}"
    else
        echo -e "${RED}✗ Failed to start Ollama${NC}"
        echo "Try manually: ollama serve"
        echo "Then run: ollama pull dolphin-llama3"
        exit 1
    fi
fi

# Check if dolphin-llama3 is already installed
if ollama list 2>/dev/null | grep -q "dolphin-llama3"; then
    echo -e "${GREEN}✓ Model dolphin-llama3 already downloaded${NC}"
else
    echo -e "${YELLOW}Downloading Dolphin Llama 3 (no filters)...${NC}"
    echo -e "${BLUE}This may take 5-10 minutes...${NC}"
    
    # Try to download with retry
    MAX_RETRIES=3
    RETRY=0
    SUCCESS=0
    
    while [ $RETRY -lt $MAX_RETRIES ]; do
        ollama pull dolphin-llama3
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Model dolphin-llama3 downloaded${NC}"
            SUCCESS=1
            break
        fi
        
        RETRY=$((RETRY + 1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Retry $RETRY of $MAX_RETRIES...${NC}"
            sleep 3
        fi
    done
    
    if [ $SUCCESS -eq 0 ]; then
        echo -e "${RED}✗ Error downloading model after $MAX_RETRIES attempts${NC}"
        echo -e "${YELLOW}You can download it later with:${NC}"
        echo "  1. Make sure Ollama is running: ollama serve"
        echo "  2. Download model: ollama pull dolphin-llama3"
    fi
fi

# ====================================
# VERIFY STRUCTURE
# ====================================
echo ""
echo -e "${YELLOW}Verifying files...${NC}"

MISSING=0

if [ ! -f "app.py" ]; then
    echo -e "${RED}✗ Missing app.py${NC}"
    MISSING=$((MISSING + 1))
fi

if [ ! -f "app_guardtrail.py" ]; then
    echo -e "${RED}✗ Missing app_guardtrail.py${NC}"
    MISSING=$((MISSING + 1))
fi

if [ ! -d "templates" ]; then
    echo -e "${RED}✗ Missing templates/ folder${NC}"
    MISSING=$((MISSING + 1))
fi

if [ ! -d "static" ]; then
    echo -e "${RED}✗ Missing static/ folder${NC}"
    MISSING=$((MISSING + 1))
fi

if [ $MISSING -gt 0 ]; then
    echo -e "${YELLOW}⚠ Missing $MISSING files/folders${NC}"
else
    echo -e "${GREEN}✓ Complete structure${NC}"
fi

# ====================================
# SUMMARY
# ====================================
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Setup completed${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Model: Dolphin Llama 3 (no filters)"
echo "  CPUs: $CPU_CORES cores"
echo ""
echo -e "${BLUE}Run:${NC}"
echo "  ./run.sh               - App WITHOUT AI Guard"
echo "  ./run_guardtrail.sh    - App WITH AI Guard"
echo ""
echo -e "${BLUE}Configure AI Guard (optional):${NC}"
echo "  export V1_API_KEY=\"your-api-key\""
echo "  ./run_guardtrail.sh"
echo ""
echo -e "${BLUE}Tools:${NC}"
echo "  ./stop.sh              - Stop app"
echo "  ./status.sh            - View status"
echo ""

