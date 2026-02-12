#!/bin/bash

echo "=========================================="
echo "  Trend Micro AI - Starting Application"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verify venv exists
if [ ! -d "venv" ]; then
    echo -e "${RED}✗ Setup not completed${NC}"
    echo "Run first: ./setup.sh"
    exit 1
fi

# Create logs folder if doesn't exist
mkdir -p logs
touch logs/ollama.log
touch logs/app.log

# Load optimized Ollama configuration if exists
if [ -f ~/.ollama_env ]; then
    source ~/.ollama_env
    echo -e "${GREEN}✓ Optimized Ollama configuration loaded${NC}"
fi

# Configure environment variables for performance
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=5m

# Detect CPUs and configure threads
CPU_CORES=$(nproc)
NUM_THREADS=$((CPU_CORES / 2))
if [ $NUM_THREADS -gt 8 ]; then
    NUM_THREADS=8
fi
export OLLAMA_NUM_THREAD=$NUM_THREADS

echo -e "${BLUE}Performance configuration:${NC}"
echo -e "  Available CPUs: $CPU_CORES"
echo -e "  Threads for Ollama: $NUM_THREADS"
echo ""

# Activate virtual environment
source venv/bin/activate

# 1. Start Ollama in background
echo -e "${YELLOW}[1/2] Starting Ollama...${NC}"
if pgrep -x "ollama" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama already running${NC}"
else
    nohup ollama serve > logs/ollama.log 2>&1 &
    OLLAMA_PID=$!
    sleep 3
    
    if pgrep -x "ollama" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ollama started (PID: $OLLAMA_PID)${NC}"
    else
        echo -e "${RED}✗ Error starting Ollama${NC}"
        echo "Check logs/ollama.log"
        exit 1
    fi
fi

# 2. Start Flask application in background
echo ""
echo -e "${YELLOW}[2/2] Starting Flask application...${NC}"

# Check if port 5000 is in use
if command -v lsof &> /dev/null; then
    if lsof -ti:5000 > /dev/null 2>&1; then
        echo -e "${YELLOW}! Port 5000 in use, stopping previous process...${NC}"
        kill -9 $(lsof -ti:5000) 2>/dev/null
        sleep 2
    fi
fi

nohup python3 app.py > logs/app.log 2>&1 &
APP_PID=$!
sleep 3

# Verify app is running
if ps -p $APP_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application started (PID: $APP_PID)${NC}"
else
    echo -e "${RED}✗ Error starting application${NC}"
    echo "Check logs/app.log for details"
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Application running!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Access:${NC}           http://localhost:5000"
echo -e "${BLUE}Ollama Logs:${NC}      tail -f logs/ollama.log"
echo -e "${BLUE}App Logs:${NC}         tail -f logs/app.log"
echo ""
echo -e "${BLUE}Performance:${NC}"
echo -e "  ⚡ Using $NUM_THREADS CPU threads"
echo -e "  ⚡ Parallel processing enabled"
echo -e "  ⚡ Model kept in memory"
echo ""
echo -e "${YELLOW}To stop:${NC}          ./stop.sh"
echo -e "${YELLOW}To view status:${NC}   ./status.sh"
echo ""

