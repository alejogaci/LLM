#!/bin/bash

echo "=========================================="
echo "  Starting - WITH AI Guard"
echo "=========================================="
echo ""

# Verify API Key
if [ -z "$V1_API_KEY" ]; then
    echo "⚠️  ERROR: V1_API_KEY not configured"
    echo ""
    echo "Configure your API Key:"
    echo "  export V1_API_KEY=\"your-api-key\""
    echo ""
    echo "Or run setup.sh again"
    exit 1
fi

# Load configuration if exists
if [ -f ~/.guardtrail_config ]; then
    source ~/.guardtrail_config
fi

# Detect CPUs
CPU_CORES=$(nproc)
NUM_THREADS=$((CPU_CORES / 2))
if [ $NUM_THREADS -gt 8 ]; then
    NUM_THREADS=8
fi

# Configure variables
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=5m
export OLLAMA_NUM_THREAD=$NUM_THREADS

# Create logs directory
mkdir -p logs

# Activate venv
source venv/bin/activate

echo "Configuration:"
echo "  CPUs: $CPU_CORES"
echo "  Threads: $NUM_THREADS"
echo "  AI Guard: ENABLED"
echo "  Port: 5000"
echo ""

# Start Ollama if not running
if ! pgrep -x "ollama" > /dev/null 2>&1; then
    echo "Starting Ollama..."
    nohup ollama serve > logs/ollama.log 2>&1 &
    sleep 3
fi

# Run app_guardtrail.py
nohup python3 app_guardtrail.py > logs/app.log 2>&1 &
PID=$!
echo $PID > logs/app.pid

sleep 2

if ps -p $PID > /dev/null; then
    echo "✓ Application started (PID: $PID)"
    echo ""
    echo "Access: http://localhost:5000"
    echo "Logs: tail -f logs/app.log"
    echo "Stop: ./stop.sh"
else
    echo "✗ Error starting application"
    cat logs/app.log
fi
