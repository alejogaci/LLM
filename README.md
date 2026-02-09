# Trend Micro AI Assistant - LLM con Interfaz Moderna

Aplicación de chat con IA usando modelos libres (Llama, Mistral) con interfaz web sofisticada en colores de Trend Micro.

---

## 🚀 INICIO RÁPIDO (2 comandos)

```bash
# 1. Instalar (solo primera vez - tarda 10 min)
./setup.sh

# 2. Ejecutar (todo en segundo plano)
./run.sh
```

**Acceso:** `http://localhost:5000` (o `http://IP_PUBLICA:5000` en AWS)

---

## 📋 COMANDOS PRINCIPALES

| Comando | Qué hace |
|---------|----------|
| `./setup.sh` | Instala Ollama, modelo IA, dependencias (solo 1 vez) |
| `./run.sh` | Inicia TODO en segundo plano |
| `./stop.sh` | Detiene TODO |
| `./status.sh` | Muestra estado de servicios y logs |

---

## 📂 ESTRUCTURA DE ARCHIVOS

```
trend-ai-assistant/
├── app.py                 # Backend Flask
├── requirements.txt       # Dependencias Python
├── README.md              # Esta guía
│
├── setup.sh               # ⭐ Instalación
├── run.sh                 # ⭐ Ejecutar
├── stop.sh                # ⭐ Detener
├── status.sh              # ⭐ Ver estado
│
├── templates/
│   └── index.html         # Interfaz web
│
├── static/
│   ├── css/
│   │   └── style.css      # Estilos Trend Micro
│   └── js/
│       └── script.js      # JavaScript
│
└── logs/                  # Se crea automáticamente
    ├── app.log
    └── ollama.log
```

---

## ✨ CARACTERÍSTICAS

- 🎨 **Interfaz moderna** con colores Trend Micro (rojos/oscuros)
- ⚡ **Streaming en tiempo real** (respuestas letra por letra)
- 🤖 **Modelos libres** (Llama 3.2, Mistral, Phi-3)
- 🔄 **Todo en segundo plano** (no necesitas múltiples terminales)
- 📊 **Logs completos** guardados en archivos

---

## 🖥️ REQUISITOS

- **Linux:** Ubuntu 22.04+ (recomendado)
- **Python:** 3.8 o superior
- **RAM:** 8 GB mínimo
- **Espacio:** ~5 GB

---

## ☁️ DESPLIEGUE EN AWS

### Security Group:
```
Type: Custom TCP
Port: 5000
Source: 0.0.0.0/0 (o tu IP)
```

### Instancia recomendada:
```
AMI: Ubuntu Server 22.04 LTS
Tipo: t3.large (8 GB RAM)
Storage: 30 GB
```

### Pasos:
```bash
# 1. Conectar
ssh -i key.pem ubuntu@IP_PUBLICA

# 2. Subir archivos (desde tu PC)
scp -i key.pem -r trend-ai-assistant ubuntu@IP_PUBLICA:~/

# 3. En el servidor
cd trend-ai-assistant
chmod +x *.sh
./setup.sh
./run.sh

# 4. Acceder
# http://IP_PUBLICA:5000
```

---

## 🔧 VER LOGS

```bash
# Ver estado general
./status.sh

# Logs en tiempo real
tail -f logs/app.log      # Aplicación
tail -f logs/ollama.log   # IA

# Últimas 50 líneas
tail -n 50 logs/app.log
```

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### Problema: No inicia
```bash
./status.sh              # Ver qué está mal
cat logs/app.log         # Ver error específico
./stop.sh && ./run.sh    # Reiniciar
```

### Problema: Puerto ocupado
```bash
kill -9 $(lsof -ti:5000)  # Liberar puerto
./run.sh
```

### Problema: Ollama no responde
```bash
pkill ollama              # Matar proceso
./run.sh                  # Reiniciar
```

---

## ⚙️ CONFIGURACIÓN

### Cambiar modelo:
Edita `app.py` línea 9:
```python
MODEL = "llama3.2"  # Cambiar a "mistral", "phi3", etc.
```

### Cambiar puerto:
Edita `app.py` última línea:
```python
app.run(debug=False, host='0.0.0.0', port=5000)
```

### Instalar otros modelos:
```bash
ollama pull mistral
ollama pull phi3
ollama list  # Ver instalados
```

---

## 🎯 FLUJO DE TRABAJO

### Primera instalación:
```bash
./setup.sh    # 10-15 minutos
./run.sh      # 5 segundos
```

### Uso diario:
```bash
./run.sh      # Iniciar
./stop.sh     # Detener
```

### Testing con GuardTrail:
1. Configura GuardTrail para monitorear puerto 5000
2. La app genera tráfico LLM real
3. Logs disponibles en `logs/`

---

## 📊 RECURSOS DEL SISTEMA

| Componente | RAM | CPU |
|-----------|-----|-----|
| Ollama + Llama 3.2 | ~3-4 GB | 10-50% |
| Flask App | ~50 MB | 1-5% |
| **Total** | **~4 GB** | **~15-55%** |

---

## 📞 CHEAT SHEET

```bash
# Instalación
./setup.sh

# Control
./run.sh        # Iniciar
./stop.sh       # Detener
./status.sh     # Estado

# Logs
tail -f logs/app.log      # Ver logs app
tail -f logs/ollama.log   # Ver logs IA

# Reiniciar
./stop.sh && ./run.sh

# Verificar procesos
ps aux | grep ollama
ps aux | grep python
```

---

## 🔒 NOTAS DE SEGURIDAD

- La app acepta conexiones externas (`0.0.0.0:5000`)
- Para producción: usar Nginx + HTTPS
- Restringir Security Group a IPs específicas
- Revisar logs periódicamente

---

**Desarrollado para testing con GuardTrail de Trend Micro** 🔴⚫
