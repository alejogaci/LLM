#!/bin/bash

echo "=========================================="
echo "  Starting - WITH AI Guard (Simple)"
echo "=========================================="
echo ""

# Check API Key directly from environment
if [ -z "$V1_API_KEY" ]; then
    echo "❌ ERROR: V1_API_KEY not set in environment"
    echo ""
    echo "In the SAME shell, run:"
    echo "  export V1_API_KEY=\"your-key\""
    echo "  ./run_guardtrail_simple.sh"
    exit 1
fi

echo "✓ API Key found: ${V1_API_KEY:0:20}..."
echo ""

# Detect CPUs
CPU_CORES=$(nproc)
NUM_THREADS=$((CPU_CORES / 2))
[ $NUM_THREADS -gt 8 ] && NUM_THREADS=8

# Configure variables
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=5m
export OLLAMA_NUM_THREAD=$NUM_THREADS

# Create logs directory
mkdir -p logs

# Activate venv
if [ ! -d "venv" ]; then
    echo "❌ venv not found. Run ./setup.sh first"
    exit 1
fi

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
echo "Starting app with AI Guard..."
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
    echo "❌ Error starting application"
    tail -20 logs/app.log
fi
