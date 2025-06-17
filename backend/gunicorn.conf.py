# gunicorn.conf.py
import os

# Server socket
bind = f"0.0.0.0:{os.environ.get('PORT', 8081)}"
backlog = 2048

# Worker processes
workers = 2
worker_class = "sync"
worker_connections = 1000
timeout = 300
keepalive = 2

# Restart workers after this many requests
max_requests = 1000
max_requests_jitter = 50

# Logging
accesslog = "/home/yrefy-it/yrefy-llm/data/logs/access.log"
errorlog = "/home/yrefy-it/yrefy-llm/data/logs/error.log"
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = "yrefy-llm-backend"

# Security
limit_request_line = 4096
limit_request_fields = 100
limit_request_field_size = 8190