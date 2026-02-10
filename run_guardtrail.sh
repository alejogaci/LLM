#!/bin/bash

echo "=========================================="
echo "  Iniciando - CON AI Guard"
echo "=========================================="
echo ""

# Verificar API Key
if [ -z "$V1_API_KEY" ]; then
    echo "⚠️  ERROR: V1_API_KEY no configurado"
    echo ""
    echo "Configura tu API Key:"
    echo "  export V1_API_KEY=\"tu-api-key\""
    echo ""
    echo "O ejecuta setup.sh de nuevo"
    exit 1
fi

# Cargar configuración si existe
if [ -f ~/.guardtrail_config ]; then
    source ~/.guardtrail_config
fi

# Detectar CPUs
CPU_CORES=$(nproc)
NUM_THREADS=$((CPU_CORES / 2))
if [ $NUM_THREADS -gt 8 ]; then
    NUM_THREADS=8
fi

# Configurar variables
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=5m
export OLLAMA_NUM_THREAD=$NUM_THREADS

# Crear directorio de logs
mkdir -p logs

# Activar venv
source venv/bin/activate

echo "Configuración:"
echo "  CPUs: $CPU_CORES"
echo "  Threads: $NUM_THREADS"
echo "  AI Guard: HABILITADO"
echo "  Puerto: 5000"
echo ""

# Ejecutar app_guardtrail.py
nohup python3 app_guardtrail.py > logs/app.log 2>&1 &
PID=$!
echo $PID > logs/app.pid

sleep 2

if ps -p $PID > /dev/null; then
    echo "✓ Aplicación iniciada (PID: $PID)"
    echo ""
    echo "Acceder: http://localhost:5000"
    echo "Logs: tail -f logs/app.log"
    echo "Detener: ./stop.sh"
else
    echo "✗ Error al iniciar"
    cat logs/app.log
fi
