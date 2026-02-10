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
MODEL = "llama3.2"  # Puedes cambiar a "mistral", "phi3", etc.

# Configurar Ollama para usar más CPU
os.environ['OLLAMA_NUM_PARALLEL'] = '4'  # Procesar hasta 4 requests en paralelo
os.environ['OLLAMA_MAX_LOADED_MODELS'] = '1'  # Mantener modelo en memoria

# Cache simple (se actualiza cada 20 segundos)
_cache = {"timestamp": 0, "data": {}}
CACHE_TTL = 20  # segundos

# ==================================================================
# FUNCIONES PARA OBTENER INFORMACIÓN DEL SISTEMA Y AWS
# ==================================================================

def get_system_info():
    """Obtiene información del sistema operativo y hardware"""
    try:
        info = {
            "sistema_operativo": platform.system(),
            "version_os": platform.release(),
            "distribucion": platform.platform(),
            "arquitectura": platform.machine(),
            "cpu_nucleos": psutil.cpu_count(logical=False),
            "cpu_threads": psutil.cpu_count(logical=True),
            "cpu_uso_porcentaje": psutil.cpu_percent(interval=0.5),
            "ram_total_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "ram_disponible_gb": round(psutil.virtual_memory().available / (1024**3), 2),
            "ram_uso_porcentaje": psutil.virtual_memory().percent,
            "disco_total_gb": round(psutil.disk_usage('/').total / (1024**3), 2),
            "disco_usado_gb": round(psutil.disk_usage('/').used / (1024**3), 2),
            "disco_libre_gb": round(psutil.disk_usage('/').free / (1024**3), 2),
            "disco_uso_porcentaje": psutil.disk_usage('/').percent
        }
        return info
    except Exception as e:
        return {"error": str(e)}

def get_aws_metadata():
    """Obtiene metadatos de AWS EC2 (si está en AWS)"""
    try:
        metadata = {}
        base_url = "http://169.254.169.254/latest/meta-data/"
        
        # Campos de metadatos de AWS
        fields = {
            "instance_id": "instance-id",
            "instance_type": "instance-type",
            "availability_zone": "placement/availability-zone",
            "region": "placement/region",
            "public_ipv4": "public-ipv4",
            "local_ipv4": "local-ipv4",
            "hostname": "hostname",
            "ami_id": "ami-id",
            "vpc_id": "network/interfaces/macs/{mac}/vpc-id",
            "subnet_id": "network/interfaces/macs/{mac}/subnet-id"
        }
        
        # Obtener MAC address primero para VPC/Subnet
        mac = None
        try:
            mac_response = requests.get(f"{base_url}network/interfaces/macs/", timeout=1)
            if mac_response.status_code == 200:
                mac = mac_response.text.strip().split('\n')[0].strip('/')
        except:
            pass
        
        for key, path in fields.items():
            try:
                if '{mac}' in path and mac:
                    path = path.format(mac=mac)
                response = requests.get(f"{base_url}{path}", timeout=0.8)
                if response.status_code == 200:
                    metadata[key] = response.text
            except:
                pass
        
        return metadata if metadata else {"error": "No está en AWS o metadatos no disponibles"}
    except Exception as e:
        return {"error": str(e)}

def get_iam_role_info():
    """Obtiene las credenciales COMPLETAS del rol IAM"""
    try:
        base_url = "http://169.254.169.254/latest/meta-data/iam/"
        
        # Obtener nombre del rol
        role_response = requests.get(f"{base_url}security-credentials/", timeout=1.5)
        if role_response.status_code != 200:
            return {"error": "No hay rol IAM asociado a esta instancia"}
        
        role_name = role_response.text.strip()
        
        # Obtener credenciales del rol COMPLETAS
        creds_response = requests.get(f"{base_url}security-credentials/{role_name}", timeout=1.5)
        if creds_response.status_code == 200:
            credentials = json.loads(creds_response.text)
            
            return {
                "rol_nombre": role_name,
                "access_key_id": credentials.get("AccessKeyId", "N/A"),
                "secret_access_key": credentials.get("SecretAccessKey", "N/A"),
                "token": credentials.get("Token", "N/A"),
                "expiracion": credentials.get("Expiration", "N/A"),
                "tipo": credentials.get("Type", "N/A"),
                "ultimo_actualizado": credentials.get("LastUpdated", "N/A"),
                "code": credentials.get("Code", "N/A")
            }
        
        return {"rol_nombre": role_name, "credenciales": "No disponibles"}
        
    except Exception as e:
        return {"error": str(e)}

def get_ec2_instances():
    """Lista todas las instancias EC2 en la cuenta/región actual"""
    # Usar cache si está fresco
    global _cache
    if time.time() - _cache["timestamp"] < CACHE_TTL and "ec2_instances" in _cache["data"]:
        return _cache["data"]["ec2_instances"]
    
    try:
        # Obtener región desde metadatos
        metadata = get_aws_metadata()
        region = metadata.get('region', 'us-east-1')
        
        # Crear cliente EC2
        ec2 = boto3.client('ec2', region_name=region)
        
        # Describir todas las instancias
        response = ec2.describe_instances()
        
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                # Obtener nombre de la instancia
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
        
        # Guardar en cache
        _cache["data"]["ec2_instances"] = instances
        _cache["timestamp"] = time.time()
        
        return instances
        
    except NoCredentialsError:
        return {"error": "No hay credenciales AWS disponibles"}
    except ClientError as e:
        return {"error": f"Error de AWS: {str(e)}"}
    except Exception as e:
        return {"error": str(e)}

def get_security_groups():
    """Obtiene los security groups de la instancia actual"""
    try:
        metadata = get_aws_metadata()
        region = metadata.get('region', 'us-east-1')
        instance_id = metadata.get('instance_id')
        
        if not instance_id:
            return {"error": "No se pudo obtener el ID de instancia"}
        
        ec2 = boto3.client('ec2', region_name=region)
        
        # Obtener información de la instancia
        response = ec2.describe_instances(InstanceIds=[instance_id])
        
        security_groups = []
        if response['Reservations']:
            instance = response['Reservations'][0]['Instances'][0]
            for sg in instance.get('SecurityGroups', []):
                # Obtener reglas del security group
                sg_details = ec2.describe_security_groups(GroupIds=[sg['GroupId']])
                if sg_details['SecurityGroups']:
                    sg_info = sg_details['SecurityGroups'][0]
                    
                    security_groups.append({
                        "id": sg['GroupId'],
                        "nombre": sg['GroupName'],
                        "descripcion": sg_info.get('Description', 'N/A'),
                        "vpc_id": sg_info.get('VpcId', 'N/A'),
                        "reglas_entrada": len(sg_info.get('IpPermissions', [])),
                        "reglas_salida": len(sg_info.get('IpPermissionsEgress', []))
                    })
        
        return security_groups
        
    except Exception as e:
        return {"error": str(e)}

def get_process_info():
    """Obtiene información de procesos corriendo"""
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            try:
                pinfo = proc.info
                if pinfo['cpu_percent'] > 1.0 or pinfo['memory_percent'] > 1.0:
                    processes.append({
                        "pid": pinfo['pid'],
                        "nombre": pinfo['name'],
                        "cpu_porcentaje": round(pinfo['cpu_percent'], 2),
                        "memoria_porcentaje": round(pinfo['memory_percent'], 2)
                    })
            except:
                pass
        
        # Ordenar por uso de CPU
        processes.sort(key=lambda x: x['cpu_porcentaje'], reverse=True)
        return processes[:5]  # Top 5 procesos (antes 10)
    except Exception as e:
        return {"error": str(e)}

def get_network_info():
    """Obtiene información de red"""
    try:
        net_io = psutil.net_io_counters()
        info = {
            "bytes_enviados_mb": round(net_io.bytes_sent / (1024**2), 2),
            "bytes_recibidos_mb": round(net_io.bytes_recv / (1024**2), 2),
            "paquetes_enviados": net_io.packets_sent,
            "paquetes_recibidos": net_io.packets_recv
        }
        return info
    except Exception as e:
        return {"error": str(e)}

def build_system_context_optimized(user_message):
    """Construye contexto SOLO con lo necesario según la pregunta"""
    context = ""
    msg_lower = user_message.lower()
    
    # Detectar qué información específica necesita
    needs_system = any(k in msg_lower for k in ['cpu', 'ram', 'memoria', 'disco', 'sistema', 'especificaciones', 'servidor', 'recursos'])
    needs_aws = any(k in msg_lower for k in ['aws', 'región', 'ip', 'instancia', 'ec2', 'vpc', 'subnet', 'ami'])
    needs_iam = any(k in msg_lower for k in ['iam', 'rol', 'credencial', 'access', 'token', 'secret', 'key'])
    needs_instances = any(k in msg_lower for k in ['instancias', 'servidores', 'otras', 'cuenta', 'lista'])
    needs_sg = any(k in msg_lower for k in ['security', 'grupo', 'firewall', 'reglas'])
    
    # Contexto base
    context = "Información disponible del sistema:\n\n"
    
    # Solo incluir lo necesario
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
            enhanced_prompt = user_message
            
            # Keywords para detectar preguntas sobre sistema/AWS
            keywords = ['sistema', 'aws', 'servidor', 'instancia', 'cpu', 'ram', 'memoria', 
                       'disco', 'red', 'procesos', 'ec2', 'región', 'ip', 'iam', 'rol',
                       'credenciales', 'security', 'vpc', 'subnet', 'servidores', 'instancias']
            
            if any(keyword in user_message.lower() for keyword in keywords):
                # Contexto optimizado solo con lo necesario
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
                    "num_thread": 8,  # Usar 8 threads de CPU
                    "num_gpu": 0,  # No usar GPU
                    "num_ctx": 2048  # Contexto de 2048 tokens (suficiente)
                }
            }
            
            response = requests.post(OLLAMA_API, json=payload, stream=True)
            
            for line in response.iter_lines():
                if line:
                    json_response = json.loads(line)
                    if 'response' in json_response:
                        yield f"data: {json.dumps({'token': json_response['response']})}\n\n"
                    
                    if json_response.get('done', False):
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
        "security_groups": get_security_groups(),
        "procesos_top": get_process_info(),
        "red": get_network_info()
    })

@app.route('/api/aws/iam-credentials', methods=['GET'])
def iam_credentials():
    """Endpoint específico para obtener credenciales IAM completas"""
    return jsonify(get_iam_role_info())

@app.route('/api/aws/ec2-instances', methods=['GET'])
def ec2_instances():
    """Endpoint específico para listar instancias EC2"""
    return jsonify(get_ec2_instances())

@app.route('/api/models', methods=['GET'])
def get_models():
    try:
        response = requests.get("http://localhost:11434/api/tags")
        return jsonify(response.json())
    except:
        return jsonify({"models": []})

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000, threaded=True)
