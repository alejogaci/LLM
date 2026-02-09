from flask import Flask, render_template, request, jsonify, Response
import requests
import json
from datetime import datetime

app = Flask(__name__)

# Configuración de Ollama (modelo local libre)
OLLAMA_API = "http://localhost:11434/api/generate"
MODEL = "llama3.2"  # Puedes cambiar a "mistral", "phi3", etc.

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    data = request.json
    user_message = data.get('message', '')
    
    def generate():
        try:
            payload = {
                "model": MODEL,
                "prompt": user_message,
                "stream": True
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

@app.route('/api/models', methods=['GET'])
def get_models():
    try:
        response = requests.get("http://localhost:11434/api/tags")
        return jsonify(response.json())
    except:
        return jsonify({"models": []})

if __name__ == '__main__':
    # Para producción en AWS, cambiar debug=False
    # Si usas HTTPS/SSL, configura un reverse proxy (nginx/apache)
    app.run(debug=False, host='0.0.0.0', port=5000, threaded=True)
