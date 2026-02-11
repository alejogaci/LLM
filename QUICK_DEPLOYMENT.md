## 🚀 Quick Deploy (CloudFormation)

Deploy everything automatically with one click:

### **1. Launch Stack**
```bash
aws cloudformation create-stack \
  --stack-name poc-ai-guard \
  --template-body file://cloudformation-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=VisionOneAPIKey,ParameterValue=YOUR_API_KEY \
    ParameterKey=InstanceSize,ParameterValue=c5a.xlarge \
    ParameterKey=SSHKeyName,ParameterValue=YOUR_KEY_NAME
```

### **2. Get App URL**
```bash
aws cloudformation describe-stacks \
  --stack-name poc-ai-guard \
  --query 'Stacks[0].Outputs[?OutputKey==`AppURL`].OutputValue' \
  --output text
```

### **3. Access**
Open the URL from step 2 in your browser (wait 5-10 min for deployment).

**What gets deployed:**
- ✅ VPC + Subnet + Internet Gateway
- ✅ EC2 Instance (c5a.xlarge/2xlarge/4xlarge)
- ✅ IAM Role with full permissions
- ✅ Security Group (SSH + port 5000)
- ✅ LLM app running **WITHOUT** AI Guard
- ✅ Dolphin Llama 3 model downloaded
- ✅ API Key pre-configured

**To enable AI Guard:**
```bash
ssh -i your-key.pem ubuntu@INSTANCE_IP
cd /home/ubuntu/LLM
./stop.sh
./run_guardtrail.sh
```

---

## 📦 Files

- **`app.py`** → App WITHOUT AI Guard
- **`app_guardtrail.py`** → App WITH AI Guard

---

## 🔄 Manual Installation

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
export V1_API_KEY="your-api-key"
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

## 🔍 Code Differences: app.py vs app_guardtrail.py

### **Visual Comparison**

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER SENDS MESSAGE                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
      ┌───────────────┐          ┌───────────────────┐
      │    app.py     │          │ app_guardtrail.py │
      │  (NO Guard)   │          │   (WITH Guard)    │
      └───────┬───────┘          └─────────┬─────────┘
              │                            │
              │                            ▼
              │                  ┌──────────────────────┐
              │                  │ 1. Call AI Guard API │
              │                  │   Validate prompt    │
              │                  └──────────┬───────────┘
              │                            │
              │                      ┌─────┴─────┐
              │                      │           │
              │                   BLOCK        ALLOW
              │                      │           │
              │                      ▼           │
              │              ┌──────────────┐   │
              │              │ Return error │   │
              │              │   message    │   │
              │              └──────────────┘   │
              │                                  │
              ▼                                  ▼
      ┌────────────────────────────────────────────┐
      │        2. Send to Ollama LLM               │
      │           (Dolphin Llama 3)                │
      └────────────────┬───────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ 3. Get response │
              └────────┬────────┘
                       │
       ┌───────────────┴───────────────┐
       │                               │
       ▼                               ▼
┌──────────────┐            ┌──────────────────────┐
│  Return to   │            │ 4. Validate response │
│     user     │            │    with AI Guard     │
└──────────────┘            └──────────┬───────────┘
                                       │
                                 ┌─────┴─────┐
                                 │           │
                              BLOCK        ALLOW
                                 │           │
                                 ▼           ▼
                         ┌──────────┐  ┌──────────┐
                         │  Block   │  │ Return   │
                         │ response │  │ to user  │
                         └──────────┘  └──────────┘
```

---

### **Key Code Addition in app_guardtrail.py**

#### **1. AI Guard Validation Function**
```python
def run_guardtrail(text):
    """Validate text with Trend Micro AI Guard"""
    
    payload = {"guard": text}  # ← User prompt captured here
    
    headers = {
        "Authorization": f"Bearer {GUARDTRAIL_API_KEY}",
        "Content-Type": "application/json"
    }
    
    # Send to AI Guard API
    response = requests.post(
        "https://api.xdr.trendmicro.com/beta/aiSecurity/guard",
        headers=headers,
        json=payload,
        timeout=10
    )
    
    return response.json()  # Returns: {"action": "Block"} or {"action": "Allow"}
```

#### **2. Validation Flow in Chat Endpoint**
```python
@app.route('/api/chat', methods=['POST'])
def chat():
    user_message = request.json.get('message')
    
    # ═══════════════════════════════════════════════════════
    # STEP 1: Validate INPUT (user prompt)
    # ═══════════════════════════════════════════════════════
    guard_result = run_guardtrail(user_message)  # ← Captured here
    
    if guard_result.get("action") == "Block":
        # Return blocked message to user
        return blocked_response()
    
    # ═══════════════════════════════════════════════════════
    # STEP 2: Send to LLM (only if prompt passed validation)
    # ═══════════════════════════════════════════════════════
    llm_response = call_ollama(user_message)
    
    # ═══════════════════════════════════════════════════════
    # STEP 3: Validate OUTPUT (LLM response)
    # ═══════════════════════════════════════════════════════
    guard_output = run_guardtrail(llm_response)
    
    if guard_output.get("action") == "Block":
        # Block LLM response
        return blocked_response()
    
    return llm_response  # Safe to return
```

---

### **Summary**

| Feature | app.py | app_guardtrail.py |
|---------|--------|-------------------|
| AI Guard validation | ❌ No | ✅ Yes |
| Validates user INPUT | ❌ | ✅ Before LLM |
| Validates LLM OUTPUT | ❌ | ✅ After LLM |
| API calls to Trend Micro | ❌ | ✅ 2 per message |
| API Key required | ❌ | ✅ V1_API_KEY |
| Everything else | ✅ Same | ✅ Same |

**Lines added:** ~100 lines for validation logic

**API endpoint:** `https://api.xdr.trendmicro.com/beta/aiSecurity/guard`

**Payload format:** `{"guard": "text to validate"}`

**Response format:** `{"action": "Block"}` or `{"action": "Allow"}`

---

## 🛑 Stop

```bash
./stop.sh
```

---

## 📊 Logs

```bash
# View logs in real-time
tail -f logs/app.log

# View AI Guard validations only
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
  "mode": "always_on",
  "validates": "input_and_output"
}
```

---

## 🔧 Requirements

- Ubuntu 24+
- Python 3.10+
- 8GB RAM minimum
- Trend Vision One API Key (only for AI Guard version)
