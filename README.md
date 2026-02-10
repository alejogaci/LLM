# POC - AI Guard (Trend Micro)

Proof of concept to validate prompts using Trend Micro AI Guard.

---

## 📦 Files

- **`app.py`** → Application WITHOUT AI Guard  
- **`app_guardtrail.py`** → Application WITH AI Guard  

---

## 🚀 Installation

```bash
chmod +x setup.sh
./setup.sh
```

---

## ▶️ Run

### Option 1: WITHOUT AI Guard
```bash
./run.sh
```
Port: **5000**

### Option 2: WITH AI Guard
```bash
./run_guardtrail.sh
```
Port: **5000**

### Option 3: Both in parallel
```bash
# Terminal 1 - WITHOUT AI Guard (port 5000)
./run.sh

# Terminal 2 - WITH AI Guard (port 5001)
PORT=5001 ./run_guardtrail.sh
```

---


## ⚙️ Configure API Key


```bash
export V1_API_KEY="your-api-key-here"
./run_guardtrail.sh
```

Or save it permanently:

```bash
echo 'export V1_API_KEY="your-api-key"' >> ~/.bashrc
source ~/.bashrc
```

---

## 🛑 Stop

```bash
./stop.sh
```

---

## 📊 Logs

```bash
# View logs in real time
tail -f logs/app.log

# View only AI Guard logs
tail -f logs/app.log | grep "TREND MICRO"
```

---

## 🧪 Verify AI Guard

```bash
curl http://localhost:5000/api/guardtrail/status
```

Response:
```json
{
  "enabled": true,
  "configured": true,
  "mode": "always_on"
}
```

---

## 📝 Differences

| Característica | app.py | app_guardtrail.py |
|---------------|--------|-------------------|
| AI Guard | ❌ No | ✅ Sí |
| Input validation | ❌ | ✅ |
| Output validation | ❌ | ✅ |
| API Key required | ❌ | ✅ |
| Everything else | ✅ Igual | ✅ Igual |

---

## 🔧 Requirements

- Ubuntu 24+
- Python 3.10+
- Minimum 8GB RAM
- Trend Vision One API Key (AI Guard only)


**Developed for testing with Trend Micro GuardTrail** 🔴⚫
