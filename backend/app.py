# app.py - Main Flask application
import os
import logging
from datetime import datetime
from pathlib import Path
from functools import wraps
import sqlite3
import json

from flask import Flask, request, jsonify, session
from flask_cors import CORS
from dotenv import load_dotenv
import msal
import requests
import psutil

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', '39b04bf540ffa81c95d880dd58a62c48b53cbe9b4d857f163b1df727548324ab')

# Configure CORS for Tailscale and local access
allowed_origins = os.environ.get('ALLOWED_ORIGINS', 'http://localhost:3005').split(',')
CORS(app, supports_credentials=True, origins=allowed_origins)

# Configuration
CLIENT_ID = os.environ.get('AZURE_CLIENT_ID')
CLIENT_SECRET = os.environ.get('AZURE_CLIENT_SECRET')
TENANT_ID = os.environ.get('AZURE_TENANT_ID')
AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
REDIRECT_URI = os.environ.get('REDIRECT_URI', 'http://100.71.177.68:8081/auth/callback')
OLLAMA_BASE_URL = os.environ.get('OLLAMA_BASE_URL', 'http://localhost:11434')
TAILSCALE_IP = os.environ.get('TAILSCALE_IP', '100.71.177.68')

# Setup logging with project-specific paths
logging.basicConfig(
    level=getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')),
    format='%(asctime)s [%(process)d] %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler('/home/yrefy-it/yrefy-llm/data/logs/backend.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize MSAL
msal_app = msal.ConfidentialClientApplication(
    CLIENT_ID,
    authority=AUTHORITY,
    client_credential=CLIENT_SECRET,
)

def init_database():
    """Initialize SQLite database for usage tracking"""
    db_path = Path(os.environ.get('DATABASE_PATH', '/home/yrefy-it/yrefy-llm/data/usage.db'))
    db_path.parent.mkdir(parents=True, exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS usage_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_email TEXT NOT NULL,
            user_name TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            model TEXT NOT NULL,
            prompt_length INTEGER,
            response_length INTEGER,
            processing_time REAL,
            ip_address TEXT,
            user_agent TEXT
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS api_keys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key_name TEXT NOT NULL,
            api_key TEXT NOT NULL UNIQUE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_used DATETIME,
            is_active BOOLEAN DEFAULT 1
        )
    ''')
    
    conn.commit()
    conn.close()

def require_auth(f):
    """Decorator to require valid Microsoft Graph token"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'No valid token provided'}), 401
        
        token = auth_header.split(' ')[1]
        
        try:
            # Validate token with Microsoft Graph
            graph_response = requests.get(
                'https://graph.microsoft.com/v1.0/me',
                headers={'Authorization': f'Bearer {token}'},
                timeout=10
            )
            
            if graph_response.status_code != 200:
                logger.warning(f"Token validation failed: {graph_response.status_code}")
                return jsonify({'error': 'Invalid or expired token'}), 401
            
            # Store user info in request context
            request.user = graph_response.json()
            return f(*args, **kwargs)
            
        except Exception as e:
            logger.error(f"Token validation error: {e}")
            return jsonify({'error': 'Authentication failed'}), 401
    
    return decorated_function

def log_usage(user_email, user_name, model, prompt_len, response_len, processing_time):
    """Log API usage for compliance and monitoring"""
    try:
        db_path = os.environ.get('DATABASE_PATH', '/home/yrefy-it/yrefy-llm/data/usage.db')
        conn = sqlite3.connect(db_path)
        conn.execute('''
            INSERT INTO usage_log 
            (user_email, user_name, model, prompt_length, response_length, 
             processing_time, ip_address, user_agent)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_email, user_name, model, prompt_len, response_len, 
            processing_time, request.remote_addr, request.headers.get('User-Agent', '')
        ))
        conn.commit()
        conn.close()
        
        logger.info(f"Usage logged: {user_email} used {model} - {processing_time:.2f}s")
    except Exception as e:
        logger.error(f"Failed to log usage: {e}")

# Authentication Routes
@app.route('/auth/login')
def login():
    """Initiate Microsoft login flow"""
    try:
        auth_url = msal_app.get_authorization_request_url(
            scopes=["https://graph.microsoft.com/User.Read"],
            redirect_uri=REDIRECT_URI
        )
        return jsonify({'auth_url': auth_url})
    except Exception as e:
        logger.error(f"Login initiation error: {e}")
        return jsonify({'error': 'Failed to initiate login'}), 500

@app.route('/auth/callback')
def callback():
    """Handle Microsoft login callback"""
    code = request.args.get('code')
    if not code:
        return jsonify({'error': 'No authorization code received'}), 400
    
    try:
        result = msal_app.acquire_token_by_authorization_code(
            code,
            scopes=["https://graph.microsoft.com/User.Read"],
            redirect_uri=REDIRECT_URI
        )
        
        if 'access_token' in result:
            return jsonify({
                'access_token': result['access_token'],
                'expires_in': result.get('expires_in', 3600),
                'user_info': result.get('id_token_claims', {})
            })
        else:
            logger.error(f"Token acquisition failed: {result}")
            return jsonify({'error': 'Authentication failed'}), 400
            
    except Exception as e:
        logger.error(f"Callback error: {e}")
        return jsonify({'error': 'Authentication error'}), 500

# LLM API Routes
@app.route('/api/models')
@require_auth
def get_models():
    """Get available Ollama models"""
    try:
        response = requests.get(f'{OLLAMA_BASE_URL}/api/tags', timeout=10)
        if response.status_code == 200:
            models = response.json().get('models', [])
            return jsonify({
                'models': [{
                    'name': m['name'], 
                    'size': m.get('size', 0),
                    'modified_at': m.get('modified_at')
                } for m in models]
            })
        else:
            logger.error(f"Ollama models request failed: {response.status_code}")
            return jsonify({'error': 'Failed to fetch models'}), 500
    except Exception as e:
        logger.error(f"Error fetching models: {e}")
        return jsonify({'error': 'Service unavailable'}), 503

@app.route('/api/chat', methods=['POST'])
@require_auth
def chat():
    """Main chat endpoint"""
    data = request.json
    prompt = data.get('prompt', '')
    model = data.get('model', 'llama3.1:70b')
    stream = data.get('stream', False)
    
    if not prompt:
        return jsonify({'error': 'Prompt is required'}), 400
    
    user = request.user
    start_time = datetime.now()
    
    try:
        # Prepare Ollama request
        ollama_request = {
            'model': model,
            'prompt': prompt,
            'stream': stream,
            'options': {
                'temperature': data.get('temperature', 0.7),
                'max_tokens': data.get('max_tokens', 2048),
                'top_p': data.get('top_p', 0.9)
            }
        }
        
        # Send request to Ollama
        response = requests.post(
            f'{OLLAMA_BASE_URL}/api/generate',
            json=ollama_request,
            timeout=300  # 5 minutes for large models
        )
        
        if response.status_code == 200:
            result = response.json()
            processing_time = (datetime.now() - start_time).total_seconds()
            
            # Log usage for compliance
            log_usage(
                user.get('userPrincipalName', 'unknown'),
                user.get('displayName', 'Unknown User'),
                model,
                len(prompt),
                len(result.get('response', '')),
                processing_time
            )
            
            return jsonify({
                'response': result.get('response', ''),
                'model': model,
                'processing_time': processing_time,
                'done': result.get('done', True),
                'context': result.get('context', [])
            })
        else:
            logger.error(f"Ollama error: {response.status_code} - {response.text}")
            return jsonify({'error': 'LLM service error'}), 500
            
    except requests.Timeout:
        logger.warning(f"Request timeout for user {user.get('userPrincipalName')}")
        return jsonify({'error': 'Request timeout - try a shorter prompt or different model'}), 504
    except Exception as e:
        logger.error(f"Chat error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/user/profile')
@require_auth
def user_profile():
    """Get current user profile from Microsoft Graph"""
    return jsonify(request.user)

@app.route('/api/admin/usage', methods=['GET'])
@require_auth
def get_usage_stats():
    """Get usage statistics (add admin role check in production)"""
    try:
        db_path = os.environ.get('DATABASE_PATH', '/home/yrefy-it/yrefy-llm/data/usage.db')
        conn = sqlite3.connect(db_path)
        
        # Get stats for last 24 hours
        cursor = conn.execute('''
            SELECT 
                COUNT(*) as total_queries,
                COUNT(DISTINCT user_email) as unique_users,
                AVG(processing_time) as avg_processing_time,
                SUM(prompt_length + response_length) as total_tokens,
                model
            FROM usage_log 
            WHERE timestamp > datetime('now', '-24 hours')
            GROUP BY model
            ORDER BY total_queries DESC
        ''')
        
        stats = [dict(zip([column[0] for column in cursor.description], row)) 
                for row in cursor.fetchall()]
        
        # Get top users
        cursor = conn.execute('''
            SELECT 
                user_email,
                COUNT(*) as query_count,
                SUM(processing_time) as total_time
            FROM usage_log 
            WHERE timestamp > datetime('now', '-24 hours')
            GROUP BY user_email
            ORDER BY query_count DESC
            LIMIT 10
        ''')
        
        top_users = [dict(zip([column[0] for column in cursor.description], row)) 
                    for row in cursor.fetchall()]
        
        conn.close()
        
        return jsonify({
            'usage_stats': stats,
            'top_users': top_users,
            'period': '24 hours'
        })
        
    except Exception as e:
        logger.error(f"Error fetching usage stats: {e}")
        return jsonify({'error': 'Failed to fetch stats'}), 500

@app.route('/health')
def health_check():
    """Health check endpoint for load balancers"""
    try:
        # Check Ollama connectivity
        response = requests.get(f'{OLLAMA_BASE_URL}/api/tags', timeout=5)
        ollama_status = 'healthy' if response.status_code == 200 else 'unhealthy'
        
        # Check system resources
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'services': {
                'ollama': ollama_status,
                'database': 'healthy'  # Could add DB check here
            },
            'system': {
                'memory_percent': memory.percent,
                'disk_percent': (disk.used / disk.total) * 100,
                'cpu_count': psutil.cpu_count()
            },
            'version': '1.0.0'
        })
    except Exception as e:
        logger.error(f"Health check error: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

# Initialize database on startup
init_database()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8081))
    host = os.environ.get('HOST', '0.0.0.0')
    
    logger.info(f"Starting Company LLM Backend on {host}:{port}")
    logger.info(f"Ollama endpoint: {OLLAMA_BASE_URL}")
    logger.info(f"Database: {os.environ.get('DATABASE_PATH')}")
    logger.info(f"Tailscale IP: {TAILSCALE_IP}")
    logger.info(f"Allowed origins: {os.environ.get('ALLOWED_ORIGINS')}")
    
    app.run(
        host=host,
        port=port,
        debug=False,
        threaded=True
    )
