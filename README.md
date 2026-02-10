# POC - AI Guard (Trend Micro)

Prueba de concepto para validar prompts con Trend Micro AI Guard.

---

## 📦 Archivos

- **`app.py`** → Aplicación SIN AI Guard
- **`app_guardtrail.py`** → Aplicación CON AI Guard

---

## 🚀 Instalación

```bash
chmod +x setup.sh
./setup.sh
```

Durante el setup te pedirá tu **Trend Vision One API Key** (opcional).

---

## ▶️ Ejecutar

### Opción 1: SIN AI Guard
```bash
./run.sh
```
Puerto: **5000**

### Opción 2: CON AI Guard
```bash
./run_guardtrail.sh
```
Puerto: **5000**

### Opción 3: Ambas en paralelo
```bash
# Terminal 1 - SIN AI Guard (puerto 5000)
./run.sh

# Terminal 2 - CON AI Guard (puerto 5001)
PORT=5001 ./run_guardtrail.sh
```

---


## ⚙️ Configurar API Key después

Si no configuraste durante el setup:

```bash
export V1_API_KEY="tu-api-key-aqui"
./run_guardtrail.sh
```

O guardar permanentemente:

```bash
echo 'export V1_API_KEY="tu-api-key"' >> ~/.bashrc
source ~/.bashrc
```

---

## 🛑 Detener

```bash
./stop.sh
```

---

## 📊 Logs

```bash
# Ver logs en tiempo real
tail -f logs/app.log

# Ver solo AI Guard
tail -f logs/app.log | grep "TREND MICRO"
```

---

## 🧪 Verificar AI Guard

```bash
curl http://localhost:5000/api/guardtrail/status
```

Respuesta:
```json
{
  "enabled": true,
  "configured": true,
  "mode": "always_on"
}
```

---

## 📝 Diferencias

| Característica | app.py | app_guardtrail.py |
|---------------|--------|-------------------|
| AI Guard | ❌ No | ✅ Sí |
| Valida INPUT | ❌ | ✅ |
| Valida OUTPUT | ❌ | ✅ |
| API Key requerida | ❌ | ✅ |
| Todo lo demás | ✅ Igual | ✅ Igual |

---

## 🔧 Requisitos

- Ubuntu 24+
- Python 3.10+
- 8GB RAM mínimo
- Trend Vision One API Key (solo para AI Guard)


**Desarrollado para testing con GuardTrail de Trend Micro** 🔴⚫
