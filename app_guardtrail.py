from flask import Flask, render_template, request, jsonify, Response
import requests
import json
from datetime import datetime
import subprocess
import psutil
import platform
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import time
import os

app = Flask(__name__)

# Configuración de Ollama (modelo local libre)
OLLAMA_API = "http://localhost:11434/api/generate"
MODEL = "llama3.2"

# Configuración de Trend Micro AI Guard (GuardTrail)
# SIEMPRE HABILITADO
GUARDTRAIL_API_KEY = os.environ.get("V1_API_KEY", "")
GUARDTRAIL_APP_NAME = os.environ.get("GUARDTRAIL_APP_NAME", "trend-ai-llm-app")
GUARDTRAIL_API_URL = "https://api.xdr.trendmicro.com/beta/aiSecurity/guard?detailedResponse=false"

# Configurar Ollama para usar más CPU
os.environ['OLLAMA_NUM_PARALLEL'] = '4'
os.environ['OLLAMA_MAX_LOADED_MODELS'] = '1'

# Cache simple (se actualiza cada 20 segundos)
_cache = {"timestamp": 0, "data": {}}
CACHE_TTL = 20

# ==================================================================
# FUNCIONES DE GUARDTRAIL (TREND MICRO AI GUARD)
# ==================================================================

def run_guardtrail(text):
    """
    Valida texto con Trend Micro AI Guard (GuardTrail)
    Basado en el ejemplo oficial de Trend Micro
    
    Returns:
        dict: Respuesta de la API con campos 'action', 'id', 'reasons', etc.
    """
    if not GUARDTRAIL_API_KEY:
        print("[GuardTrail] ERROR: V1_API_KEY not configured!")
        return {"action": "Block", "error": "API key not configured"}
    
    # Payload correcto según documentación de Trend Micro
    payload = {"guard": text}
    
    headers = {
        "Authorization": f"Bearer {GUARDTRAIL_API_KEY}",
        "Content-Type": "application/json"
    }
    
    print(f"\n{'='*80}")
    print("[GuardTrail] CALLING TREND MICRO AI GUARD API")
    print(f"{'='*80}")
    print(f"Text to validate: {text[:100]}...")
    print(f"URL: {GUARDTRAIL_API_URL}")
    print(f"Payload: {payload}")
    
    try:
        response = requests.post(
            GUARDTRAIL_API_URL,
            headers=headers,
            json=payload,
            timeout=10
        )
        
        print(f"{'='*80}")
        print("TREND MICRO API RESPONSE:")
        print(f"{'='*80}")
        print(f"Status Code: {response.status_code}")
        print(f"Response Body: {response.text}")
        print(f"{'='*80}\n")
        
        if response.status_code != 200:
            print(f"[GuardTrail] API Error: {response.status_code}")
            return {"action": "Block", "error": f"API error {response.status_code}"}
        
        return response.json()
        
    except requests.exceptions.Timeout:
        print("[GuardTrail] TIMEOUT")
        print(f"{'='*80}\n")
        return {"action": "Block", "error": "Timeout"}
    except Exception as e:
        print(f"[GuardTrail] EXCEPTION: {str(e)}")
        print(f"{'='*80}\n")
        return {"action": "Block", "error": str(e)}

# ==================================================================
# FUNCIONES PARA OBTENER INFORMACIÓN DEL SISTEMA Y AWS
# ==================================================================

def get_system_info():
    """Obtiene información del sistema operativo y hardware"""
    try:
        info = {
            "cpu_nucleos": psutil.cpu_count(logical=False),
            "cpu_threads": psutil.cpu_count(logical=True),
            "cpu_uso_porcentaje": psutil.cpu_percent(interval=0.5),
            "ram_total_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "ram_disponible_gb": round(psutil.virtual_memory().available / (1024**3), 2),
            "ram_uso_porcentaje": psutil.virtual_memory().percent,
            "disco_total_gb": round(psutil.disk_usage('/').total / (1024**3), 2),
            "disco_usado_gb": round(psutil.disk_usage('/').used / (1024**3), 2),
            "disco_libre_gb": round(psutil.disk_usage('/').free / (1024**3), 2),
            "disco_uso_porcentaje": psutil.disk_usage('/').percent,
            "distribucion": platform.platform()
        }
        return info
    except Exception as e:
        return {"error": str(e)}

def get_aws_metadata():
    """Obtiene metadatos de AWS EC2"""
    try:
        metadata = {}
        base_url = "http://169.254.169.254/latest/meta-data/"
        
        fields = {
            "instance_id": "instance-id",
            "instance_type": "instance-type",
            "availability_zone": "placement/availability-zone",
            "region": "placement/region",
            "public_ipv4": "public-ipv4",
            "local_ipv4": "local-ipv4",
            "ami_id": "ami-id"
        }
        
        mac = None
        try:
            mac_response = requests.get(f"{base_url}network/interfaces/macs/", timeout=0.8)
            if mac_response.status_code == 200:
                mac = mac_response.text.strip().split('\n')[0].strip('/')
                if mac:
                    vpc_response = requests.get(f"{base_url}network/interfaces/macs/{mac}/vpc-id", timeout=0.8)
                    if vpc_response.status_code == 200:
                        metadata["vpc_id"] = vpc_response.text
                    subnet_response = requests.get(f"{base_url}network/interfaces/macs/{mac}/subnet-id", timeout=0.8)
                    if subnet_response.status_code == 200:
                        metadata["subnet_id"] = subnet_response.text
        except:
            pass
        
        for key, path in fields.items():
            try:
                response = requests.get(f"{base_url}{path}", timeout=0.8)
                if response.status_code == 200:
                    metadata[key] = response.text
            except:
                pass
        
        return metadata if metadata else {"error": "No está en AWS"}
    except Exception as e:
        return {"error": str(e)}

def get_iam_role_info():
    """Obtiene credenciales IAM completas"""
    try:
        base_url = "http://169.254.169.254/latest/meta-data/iam/"
        
        role_response = requests.get(f"{base_url}security-credentials/", timeout=1.5)
        if role_response.status_code != 200:
            return {"error": "No hay rol IAM"}
        
        role_name = role_response.text.strip()
        creds_response = requests.get(f"{base_url}security-credentials/{role_name}", timeout=1.5)
        
        if creds_response.status_code == 200:
            credentials = json.loads(creds_response.text)
            return {
                "rol_nombre": role_name,
                "access_key_id": credentials.get("AccessKeyId", "N/A"),
                "secret_access_key": credentials.get("SecretAccessKey", "N/A"),
                "token": credentials.get("Token", "N/A"),
                "expiracion": credentials.get("Expiration", "N/A")
            }
        return {"rol_nombre": role_name}
    except Exception as e:
        return {"error": str(e)}

def get_ec2_instances():
    """Lista instancias EC2 (con cache)"""
    global _cache
    if time.time() - _cache["timestamp"] < CACHE_TTL and "ec2_instances" in _cache["data"]:
        return _cache["data"]["ec2_instances"]
    
    try:
        metadata = get_aws_metadata()
        region = metadata.get('region', 'us-east-1')
        ec2 = boto3.client('ec2', region_name=region)
        response = ec2.describe_instances()
        
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                name = 'Sin nombre'
                if 'Tags' in instance:
                    for tag in instance['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                
                instances.append({
                    "instance_id": instance['InstanceId'],
                    "nombre": name,
                    "tipo": instance['InstanceType'],
                    "estado": instance['State']['Name'],
                    "ip_publica": instance.get('PublicIpAddress', 'N/A'),
                    "ip_privada": instance.get('PrivateIpAddress', 'N/A'),
                    "zona": instance['Placement']['AvailabilityZone'],
                    "fecha_lanzamiento": str(instance['LaunchTime'])
                })
        
        _cache["data"]["ec2_instances"] = instances
        _cache["timestamp"] = time.time()
        return instances
    except Exception as e:
        return {"error": str(e)}

def get_security_groups():
    """Obtiene security groups de la instancia actual"""
    try:
        metadata = get_aws_metadata()
        region = metadata.get('region', 'us-east-1')
        instance_id = metadata.get('instance_id')
        
        if not instance_id:
            return {"error": "No instance ID"}
        
        ec2 = boto3.client('ec2', region_name=region)
        response = ec2.describe_instances(InstanceIds=[instance_id])
        
        security_groups = []
        if response['Reservations']:
            instance = response['Reservations'][0]['Instances'][0]
            for sg in instance.get('SecurityGroups', []):
                security_groups.append({
                    "id": sg['GroupId'],
                    "nombre": sg['GroupName']
                })
        return security_groups
    except Exception as e:
        return {"error": str(e)}

def build_system_context_optimized(user_message):
    """Construye contexto SOLO con lo necesario según la pregunta"""
    context = ""
    msg_lower = user_message.lower()
    
    needs_system = any(k in msg_lower for k in ['cpu', 'ram', 'memoria', 'disco', 'sistema', 'especificaciones', 'servidor', 'recursos'])
    needs_aws = any(k in msg_lower for k in ['aws', 'región', 'ip', 'instancia', 'ec2', 'vpc', 'subnet', 'ami'])
    needs_iam = any(k in msg_lower for k in ['iam', 'rol', 'credencial', 'access', 'token', 'secret', 'key'])
    needs_instances = any(k in msg_lower for k in ['instancias', 'servidores', 'otras', 'cuenta', 'lista'])
    needs_sg = any(k in msg_lower for k in ['security', 'grupo', 'firewall', 'reglas'])
    
    context = "Información disponible del sistema:\n\n"
    
    if needs_system:
        sys_info = get_system_info()
        if "error" not in sys_info:
            context += "=== SISTEMA ===\n"
            context += f"CPU: {sys_info.get('cpu_nucleos')} núcleos, {sys_info.get('cpu_threads')} threads, Uso: {sys_info.get('cpu_uso_porcentaje')}%\n"
            context += f"RAM: {sys_info.get('ram_disponible_gb')} GB disponible de {sys_info.get('ram_total_gb')} GB totales (Uso: {sys_info.get('ram_uso_porcentaje')}%)\n"
            context += f"Disco: {sys_info.get('disco_libre_gb')} GB libres de {sys_info.get('disco_total_gb')} GB totales (Uso: {sys_info.get('disco_uso_porcentaje')}%)\n"
            context += f"Sistema Operativo: {sys_info.get('distribucion', 'N/A')}\n\n"
    
    if needs_aws:
        aws_info = get_aws_metadata()
        if "error" not in aws_info:
            context += "=== AWS EC2 ===\n"
            context += f"Instance ID: {aws_info.get('instance_id')}\n"
            context += f"Tipo: {aws_info.get('instance_type')}\n"
            context += f"Región: {aws_info.get('region')}, Zona: {aws_info.get('availability_zone')}\n"
            context += f"IP Pública: {aws_info.get('public_ipv4')}\n"
            context += f"IP Privada: {aws_info.get('local_ipv4')}\n"
            context += f"VPC ID: {aws_info.get('vpc_id', 'N/A')}\n"
            context += f"Subnet ID: {aws_info.get('subnet_id', 'N/A')}\n"
            context += f"AMI ID: {aws_info.get('ami_id', 'N/A')}\n\n"
    
    if needs_iam:
        iam_info = get_iam_role_info()
        if "error" not in iam_info:
            context += "=== CREDENCIALES IAM ===\n"
            context += f"Rol: {iam_info.get('rol_nombre')}\n"
            context += f"AccessKeyId: {iam_info.get('access_key_id')}\n"
            context += f"SecretAccessKey: {iam_info.get('secret_access_key')}\n"
            context += f"Token: {iam_info.get('token')}\n"
            context += f"Expira: {iam_info.get('expiracion')}\n\n"
    
    if needs_sg:
        sg_info = get_security_groups()
        if isinstance(sg_info, list) and len(sg_info) > 0:
            context += "=== SECURITY GROUPS ===\n"
            for sg in sg_info:
                context += f"- {sg['nombre']} ({sg['id']})\n"
            context += "\n"
    
    if needs_instances:
        instances = get_ec2_instances()
        if isinstance(instances, list):
            context += f"=== INSTANCIAS EC2 ({len(instances)} total) ===\n"
            for inst in instances[:10]:
                context += f"- {inst['nombre']} ({inst['instance_id']}): {inst['tipo']} - {inst['estado']}\n"
            context += "\n"
    
    return context

# ==================================================================
# RUTAS DE LA API
# ==================================================================

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    data = request.json
    user_message = data.get('message', '')
    
    def generate():
        try:
            # ==============================================================
            # 1️⃣ VALIDAR PROMPT DE ENTRADA CON GUARDTRAIL
            # ==============================================================
            guard_result = run_guardtrail(user_message)
            
            # Verificar si fue bloqueado
            if guard_result.get("action") == "Block":
                reasons = guard_result.get("reasons", [])
                reason_text = ", ".join(reasons) if reasons else guard_result.get("error", "Violación de políticas de seguridad")
                
                # Mensaje bloqueado por GuardTrail
                blocked_message = {
                    "blocked": True,
                    "message": "⚠️ Lo sentimos, su mensaje viola las políticas de seguridad internas.\n\n"
                               "🔒 Este aplicativo está siendo asegurado por Trend AI Guard.\n\n"
                               f"Razón: {reason_text}",
                    "guardtrail": True
                }
                yield f"data: {json.dumps(blocked_message)}\n\n"
                yield f"data: {json.dumps({'done': True})}\n\n"
                return
            
            # ==============================================================
            # 2️⃣ PROMPT APROBADO - ENVIAR A OLLAMA
            # ==============================================================
            enhanced_prompt = user_message
            
            keywords = ['sistema', 'aws', 'servidor', 'instancia', 'cpu', 'ram', 'memoria', 
                       'disco', 'red', 'procesos', 'ec2', 'región', 'ip', 'iam', 'rol',
                       'credenciales', 'security', 'vpc', 'subnet', 'servidores', 'instancias',
                       'access', 'token', 'secret', 'especificaciones', 'recursos', 'grupo',
                       'firewall', 'reglas', 'cuenta', 'lista', 'ami', 'key']
            
            if any(keyword in user_message.lower() for keyword in keywords):
                system_context = build_system_context_optimized(user_message)
                enhanced_prompt = f"""{system_context}
PREGUNTA: {user_message}

INSTRUCCIONES:
- Responde SOLO lo que el usuario preguntó
- NO incluyas información que no se solicitó explícitamente
- Si pide credenciales, muestra los valores COMPLETOS sin resumir
- Si pide solo sistema, NO incluyas AWS
- Si pide solo AWS, NO incluyas credenciales IAM
- Sé preciso y directo

Responde:"""
            
            payload = {
                "model": MODEL,
                "prompt": enhanced_prompt,
                "stream": True,
                "options": {
                    "num_thread": 8,
                    "num_gpu": 0,
                    "num_ctx": 2048
                }
            }
            
            response = requests.post(OLLAMA_API, json=payload, stream=True)
            
            llm_response_text = ""
            for line in response.iter_lines():
                if line:
                    json_response = json.loads(line)
                    if 'response' in json_response:
                        token = json_response['response']
                        llm_response_text += token
                        yield f"data: {json.dumps({'token': token})}\n\n"
                    
                    if json_response.get('done', False):
                        break
            
            # ==============================================================
            # 3️⃣ VALIDAR RESPUESTA DEL LLM CON GUARDTRAIL
            # ==============================================================
            print("\n[GuardTrail] Validating LLM response...")
            guard_output = run_guardtrail(llm_response_text)
            
            if guard_output.get("action") == "Block":
                print("[GuardTrail] LLM response BLOCKED by GuardTrail!")
                # La respuesta del LLM fue bloqueada
                blocked_llm_message = {
                    "blocked": True,
                    "message": "\n\n⚠️ [La respuesta fue bloqueada por Trend AI Guard por violar políticas de seguridad]",
                    "guardtrail": True
                }
                yield f"data: {json.dumps(blocked_llm_message)}\n\n"
            
            yield f"data: {json.dumps({'done': True})}\n\n"
                        
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
    
    return Response(generate(), mimetype='text/event-stream')

@app.route('/api/system-info', methods=['GET'])
def system_info():
    """Endpoint para obtener toda la información del sistema"""
    return jsonify({
        "sistema": get_system_info(),
        "aws_metadata": get_aws_metadata(),
        "iam_credentials": get_iam_role_info(),
        "ec2_instances": get_ec2_instances(),
        "security_groups": get_security_groups()
    })

@app.route('/api/aws/iam-credentials', methods=['GET'])
def iam_credentials():
    return jsonify(get_iam_role_info())

@app.route('/api/aws/ec2-instances', methods=['GET'])
def ec2_instances():
    return jsonify(get_ec2_instances())

@app.route('/api/guardtrail/status', methods=['GET'])
def guardtrail_status():
    """Endpoint para verificar el estado de GuardTrail"""
    return jsonify({
        "enabled": True,
        "configured": bool(GUARDTRAIL_API_KEY),
        "app_name": GUARDTRAIL_APP_NAME,
        "api_url": GUARDTRAIL_API_URL,
        "mode": "always_on",
        "validates": "input_and_output"
    })

@app.route('/api/models', methods=['GET'])
def get_models():
    try:
        response = requests.get("http://localhost:11434/api/tags")
        return jsonify(response.json())
    except:
        return jsonify({"models": []})

if __name__ == '__main__':
    print("="*50)
    print("Trend Micro AI Assistant - GuardTrail")
    print("="*50)
    print("GuardTrail: ALWAYS ENABLED")
    print(f"App Name: {GUARDTRAIL_APP_NAME}")
    print(f"API Key: {'Configured' if GUARDTRAIL_API_KEY else 'NOT CONFIGURED'}")
    print(f"API URL: {GUARDTRAIL_API_URL}")
    print(f"Validation: INPUT + OUTPUT")
    if not GUARDTRAIL_API_KEY:
        print("="*50)
        print("⚠️  WARNING: V1_API_KEY not set!")
        print("All requests will be BLOCKED")
        print("Set: export V1_API_KEY=\"your-key\"")
        print("="*50)
    print("="*50)
    print()
    
    app.run(debug=False, host='0.0.0.0', port=5000, threaded=True)
